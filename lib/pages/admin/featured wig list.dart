import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'ad_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  FEATURED WIGS LIST
//  Live stream from Firestore 'wigs' collection.
//  Admin can:
//    • Toggle featured on/off
//    • Toggle in stock on/off
//    • Edit stock quantity inline
//    • Delete a wig (with confirmation)
// ─────────────────────────────────────────────────────────────────────────────
class FeaturedWigsList extends StatefulWidget {
  const FeaturedWigsList({super.key});

  @override
  State<FeaturedWigsList> createState() => _FeaturedWigsListState();
}

class _FeaturedWigsListState extends State<FeaturedWigsList>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double>   _fade;

  String _filterCategory = 'All';

  static const _categories = [
    'All', 'Wig Making', 'Revamping', 'Styling', 'Factory Wig'
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
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
        .collection('wigs')
        .orderBy('createdAt', descending: true);
    if (_filterCategory != 'All') {
      q = q.where('category', isEqualTo: _filterCategory);
    }
    return q;
  }

  Future<void> _toggleField(
      String docId, String field, bool currentValue) async {
    await FirebaseFirestore.instance
        .collection('wigs')
        .doc(docId)
        .update({field: !currentValue});
  }

  Future<void> _updateStock(String docId, int newStock) async {
    await FirebaseFirestore.instance.collection('wigs').doc(docId).update({
      'stock'  : newStock,
      'inStock': newStock > 0,
    });
  }

  Future<void> _deleteWig(String docId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AdTheme.cardBg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdTheme.rLg)),
        title: const Text('Delete Wig',
            style: TextStyle(
                color: AdTheme.textHigh, fontWeight: FontWeight.bold)),
        content: Text(
            'Are you sure you want to delete "$name"? This cannot be undone.',
            style: const TextStyle(color: AdTheme.textMid)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AdTheme.textMid))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(
                      color: AdTheme.error,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('wigs')
          .doc(docId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"$name" deleted.'),
          backgroundColor: AdTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  void _showEditStockSheet(
      BuildContext context, String docId, int currentStock) {
    final ctrl = TextEditingController(text: '$currentStock');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AdTheme.cardBg,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AdTheme.rXl)),
            border: Border.all(color: AdTheme.cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Update Stock',
                  style: TextStyle(
                      color: AdTheme.textHigh,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(
                    color: AdTheme.textHigh, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'New stock quantity',
                  labelStyle: const TextStyle(color: AdTheme.textMid),
                  filled: true,
                  fillColor: AdTheme.surface,
                  border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(AdTheme.rMd),
                      borderSide:
                      const BorderSide(color: AdTheme.cardBorder)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(AdTheme.rMd),
                      borderSide:
                      const BorderSide(color: AdTheme.cardBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(AdTheme.rMd),
                      borderSide: const BorderSide(
                          color: AdTheme.accent, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: AdTheme.gradientButton(
                  label: 'Update Stock',
                  icon: Icons.inventory_2_outlined,
                  gradient: AdTheme.accentGradient,
                  onTap: () async {
                    final val = int.tryParse(ctrl.text.trim()) ?? 0;
                    Navigator.pop(context);
                    await _updateStock(docId, val);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Column(
        children: [
          // ── Category filter pills ────────────────────────────────────────
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: _categories.map((cat) {
                final active = _filterCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _filterCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: active ? AdTheme.accent : AdTheme.cardBg,
                      border: Border.all(
                          color: active
                              ? AdTheme.accent
                              : AdTheme.cardBorder),
                      boxShadow: active
                          ? [BoxShadow(
                          color: AdTheme.accent.withOpacity(0.3),
                          blurRadius: 8)]
                          : [],
                    ),
                    child: Text(cat,
                        style: TextStyle(
                          color: active
                              ? Colors.white
                              : AdTheme.textMid,
                          fontSize: 12,
                          fontWeight: active
                              ? FontWeight.bold
                              : FontWeight.w500,
                        )),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // ── Live list ────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const _WigsListSkeleton();
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}',
                        style:
                        const TextStyle(color: AdTheme.error)),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return _EmptyWigsList(
                      category: _filterCategory);
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  physics: const BouncingScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final data =
                    docs[i].data() as Map<String, dynamic>;
                    return _WigAdminCard(
                      docId: docs[i].id,
                      data: data,
                      index: i,
                      onToggleFeatured: () => _toggleField(
                          docs[i].id,
                          'featured',
                          data['featured'] as bool? ?? false),
                      onToggleStock: () => _toggleField(
                          docs[i].id,
                          'inStock',
                          data['inStock'] as bool? ?? true),
                      onEditStock: () => _showEditStockSheet(
                          context,
                          docs[i].id,
                          (data['stock'] as num?)?.toInt() ?? 0),
                      onDelete: () => _deleteWig(
                          docs[i].id,
                          data['name'] as String? ?? 'Wig'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIG ADMIN CARD
// ─────────────────────────────────────────────────────────────────────────────
class _WigAdminCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final int    index;
  final VoidCallback onToggleFeatured;
  final VoidCallback onToggleStock;
  final VoidCallback onEditStock;
  final VoidCallback onDelete;

  const _WigAdminCard({
    required this.docId,
    required this.data,
    required this.index,
    required this.onToggleFeatured,
    required this.onToggleStock,
    required this.onEditStock,
    required this.onDelete,
  });

  @override
  State<_WigAdminCard> createState() => _WigAdminCardState();
}

class _WigAdminCardState extends State<_WigAdminCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _slide = Tween<Offset>(
        begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  String _categoryEmoji(String cat) {
    switch (cat) {
      case 'Wig Making':  return '🪡';
      case 'Revamping':   return '✨';
      case 'Styling':     return '💇‍♀️';
      case 'Factory Wig': return '🏭';
      default:            return '👑';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name     = widget.data['name']     as String? ?? 'Wig';
    final price    = (widget.data['price'] as num?)?.toDouble() ?? 0;
    final stock    = (widget.data['stock'] as num?)?.toInt() ?? 0;
    final imageUrl = widget.data['imageUrl'] as String? ?? '';
    final category = widget.data['category'] as String? ?? '';
    final featured = widget.data['featured'] as bool?   ?? false;
    final inStock  = widget.data['inStock']  as bool?   ?? true;
    final hairType = widget.data['hairType'] as String? ?? '';
    final length   = widget.data['length']   as String? ?? '';
    final color    = widget.data['color']    as String? ?? '';
    final wigType  = widget.data['wigType']  as String? ?? '';
    final density  = widget.data['density']  as String? ?? '';

    final stockColor = stock == 0
        ? AdTheme.error
        : stock <= 5
        ? AdTheme.warning
        : AdTheme.success;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          decoration: AdTheme.cardDecoration(
              borderColor: featured
                  ? AdTheme.accent.withOpacity(0.35)
                  : AdTheme.cardBorder),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top: image + core info ─────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft:
                      Radius.circular(AdTheme.rMd.toDouble()),
                      bottomLeft:
                      Radius.circular(AdTheme.rMd.toDouble()),
                    ),
                    child: imageUrl.isNotEmpty
                        ? Image.network(imageUrl,
                        width: 90, height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _PlaceholderImg(
                                emoji: _categoryEmoji(category)))
                        : _PlaceholderImg(
                        emoji: _categoryEmoji(category)),
                  ),

                  // Info
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name + featured badge
                          Row(
                            children: [
                              Expanded(
                                child: Text(name,
                                    style: AdTheme.titleSm,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              if (featured)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AdTheme.accent
                                        .withOpacity(0.15),
                                    borderRadius:
                                    BorderRadius.circular(10),
                                    border: Border.all(
                                        color: AdTheme.accent
                                            .withOpacity(0.4)),
                                  ),
                                  child: const Text('⭐ Featured',
                                      style: TextStyle(
                                          color: AdTheme.accent,
                                          fontSize: 9,
                                          fontWeight:
                                          FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                              '${_categoryEmoji(category)} $category',
                              style: AdTheme.caption),
                          const SizedBox(height: 6),
                          // Price + stock
                          Row(
                            children: [
                              Text('GH₵ ${price.toStringAsFixed(0)}',
                                  style: AdTheme.label
                                      .copyWith(fontSize: 14)),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: widget.onEditStock,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    borderRadius:
                                    BorderRadius.circular(20),
                                    color: stockColor
                                        .withOpacity(0.12),
                                    border: Border.all(
                                        color: stockColor
                                            .withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('$stock in stock',
                                          style: TextStyle(
                                              color: stockColor,
                                              fontSize: 10,
                                              fontWeight:
                                              FontWeight.bold)),
                                      const SizedBox(width: 4),
                                      Icon(Icons.edit_rounded,
                                          color: stockColor,
                                          size: 10),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ── Detail chips ───────────────────────────────────────────
              if (hairType.isNotEmpty ||
                  length.isNotEmpty ||
                  color.isNotEmpty ||
                  wigType.isNotEmpty ||
                  density.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Wrap(
                    spacing: 6, runSpacing: 6,
                    children: [
                      if (hairType.isNotEmpty)
                        _DetailChip(label: hairType),
                      if (length.isNotEmpty)
                        _DetailChip(label: length),
                      if (wigType.isNotEmpty && wigType != 'None')
                        _DetailChip(label: wigType),
                      if (density.isNotEmpty)
                        _DetailChip(label: density),
                      if (color.isNotEmpty)
                        _DetailChip(label: color),
                    ],
                  ),
                ),

              // ── Divider ────────────────────────────────────────────────
              Container(height: 1, color: AdTheme.cardBorder),

              // ── Action bar ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  children: [
                    // Featured toggle
                    _ActionChip(
                      icon: Icons.star_rounded,
                      label: featured ? 'Featured' : 'Feature',
                      active: featured,
                      activeColor: AdTheme.accent,
                      onTap: widget.onToggleFeatured,
                    ),
                    const SizedBox(width: 8),
                    // In-stock toggle
                    _ActionChip(
                      icon: Icons.check_circle_outline_rounded,
                      label: inStock ? 'In Stock' : 'Out of Stock',
                      active: inStock,
                      activeColor: AdTheme.success,
                      onTap: widget.onToggleStock,
                    ),
                    const Spacer(),
                    // Delete button
                    GestureDetector(
                      onTap: widget.onDelete,
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AdTheme.error.withOpacity(0.1),
                          border: Border.all(
                              color: AdTheme.error.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: AdTheme.error, size: 17),
                      ),
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

// ── Helpers ────────────────────────────────────────────────────────────────────
class _PlaceholderImg extends StatelessWidget {
  final String emoji;
  const _PlaceholderImg({required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90, height: 100,
      color: AdTheme.primary.withOpacity(0.1),
      child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 30))),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  const _DetailChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AdTheme.primary.withOpacity(0.08),
        border: Border.all(color: AdTheme.primary.withOpacity(0.2)),
      ),
      child: Text(label,
          style: const TextStyle(
              color: AdTheme.textMid,
              fontSize: 10,
              fontWeight: FontWeight.w500)),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     active;
  final Color    activeColor;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: active
              ? activeColor.withOpacity(0.12)
              : AdTheme.surface,
          border: Border.all(
              color: active
                  ? activeColor.withOpacity(0.5)
                  : AdTheme.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: active ? activeColor : AdTheme.textLow,
                size: 13),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: active ? activeColor : AdTheme.textMid,
                    fontSize: 11,
                    fontWeight: active
                        ? FontWeight.bold
                        : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── Empty & skeleton ───────────────────────────────────────────────────────────
class _EmptyWigsList extends StatelessWidget {
  final String category;
  const _EmptyWigsList({required this.category});

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
                  ? 'No wigs added yet'
                  : 'No $category wigs',
              style: AdTheme.headingMd,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Switch to the "Add Wig" tab to add your first featured wig.',
              textAlign: TextAlign.center,
              style: AdTheme.body,
            ),
          ],
        ),
      ),
    );
  }
}

class _WigsListSkeleton extends StatefulWidget {
  const _WigsListSkeleton();

  @override
  State<_WigsListSkeleton> createState() => _WigsListSkeletonState();
}

class _WigsListSkeletonState extends State<_WigsListSkeleton>
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
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AdTheme.rMd),
            color: AdTheme.cardBg.withOpacity(_anim.value),
          ),
        ),
      ),
    );
  }
}