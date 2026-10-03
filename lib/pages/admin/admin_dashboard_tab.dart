import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tiwigsstrand/pages/admin/admin%20add%20featured%20wig.dart';

import 'ad_theme.dart';

/// Admin Dashboard Home Tab
/// Firestore collections used:
///   orders   → { status, createdAt, totalAmount, customerName, items[] }
///   wigs     → { name, stock, imageUrl, category }
///   bookings → { status, createdAt, service }
///   users    → { role, createdAt }
class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({super.key});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Top greeting ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Admin Panel', style: AdTheme.caption.copyWith(letterSpacing: 2)),
                  const SizedBox(height: 4),
                  RichText(
                    text: const TextSpan(children: [
                      TextSpan(text: 'Tiwigs', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AdTheme.accent, letterSpacing: 1.2)),
                      TextSpan(text: 'strand', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AdTheme.textHigh, letterSpacing: 1.2)),
                      TextSpan(text: '  🛡️', style: TextStyle(fontSize: 22)),
                    ]),
                  ),
                  const SizedBox(height: 2),
                  Text('Business overview · today', style: AdTheme.body.copyWith(fontSize: 12)),
                ],
              ),
            ),
          ),

          // ── Stat cards ───────────────────────────────────────────────────
          const SliverToBoxAdapter(child: _StatCardsRow()),

          // ── Quick action: Add new wig ───────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _QuickActionAddWigCard(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      // AdminAddFeaturedWigs has no Scaffold of its own
                      // (it's built to live inside a tab), so we wrap it
                      // in one here to give its form fields/switches the
                      // Material ancestor they need.
                      builder: (_) => Scaffold(
                        backgroundColor: AdTheme.darkBg,
                        body: const AdminAddFeaturedWigs(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Orders today ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: AdTheme.sectionHeader('Orders Today', action: 'View all', onAction: () {}),
          ),
          const SliverToBoxAdapter(child: _OrdersTodayList()),

          // ── Low stock alert ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: AdTheme.sectionHeader('Low Stock Alert', action: 'Manage', onAction: () {

            }),
          ),
          const SliverToBoxAdapter(child: _LowStockList()),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Stat cards row ────────────────────────────────────────────────────────────
class _StatCardsRow extends StatelessWidget {
  const _StatCardsRow();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, ordersSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('bookings').snapshots(),
          builder: (context, bookSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, usersSnap) {

                // Count today's orders
                final now = DateTime.now();
                final startOfDay = DateTime(now.year, now.month, now.day);
                final allOrders  = ordersSnap.data?.docs ?? [];
                final todayOrders = allOrders.where((d) {
                  final ts = (d['createdAt'] as Timestamp?)?.toDate();
                  return ts != null && ts.isAfter(startOfDay);
                }).toList();

                // Revenue today
                double revenue = 0;
                for (final d in todayOrders) {
                  revenue += ((d.data() as Map)['totalAmount'] as num?)?.toDouble() ?? 0;
                }

                // Pending bookings
                final pendingBookings = (bookSnap.data?.docs ?? [])
                    .where((d) => (d['status'] as String?) == 'pending')
                    .length;

                // Total customers
                final totalUsers = (usersSnap.data?.docs ?? [])
                    .where((d) => (d['role'] as String?) == 'Customer')
                    .length;

                final stats = [
                  _StatData('Orders Today', '${todayOrders.length}', '📦', AdTheme.statOrders),
                  _StatData('Revenues (GH₵)', revenue.toStringAsFixed(0), '💰', AdTheme.statRevenue),
                  _StatData('Pending Bookings', '$pendingBookings', '📅', AdTheme.statBookings),
                  _StatData('Total Customers', '$totalUsers', '👥', AdTheme.statUsers),
                ];

                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.55,
                    ),
                    itemCount: stats.length,
                    itemBuilder: (_, i) => _StatCard(data: stats[i], index: i),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final String emoji;
  final Color  color;
  const _StatData(this.label, this.value, this.emoji, this.color);
}

class _StatCard extends StatefulWidget {
  final _StatData data;
  final int index;
  const _StatCard({required this.data, required this.index});

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;
  late Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _scale = Tween<double>(begin: 0.82, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AdTheme.rMd),
            color: AdTheme.cardBg,
            border: Border.all(color: d.color.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(color: d.color.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: d.color.withOpacity(0.15),
                      border: Border.all(color: d.color.withOpacity(0.3)),
                    ),
                    child: Center(child: Text(d.emoji, style: const TextStyle(fontSize: 16))),
                  ),
                  const Spacer(),
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: d.color),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.value,
                      style: AdTheme.headingLg.copyWith(
                          color: d.color, fontSize: 26, letterSpacing: -0.5)),
                  Text(d.label, style: AdTheme.caption),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Quick action card widget ────────────────────────────────────────────────
class _QuickActionAddWigCard extends StatelessWidget {
  final VoidCallback onTap;
  const _QuickActionAddWigCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AdTheme.rMd),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AdTheme.rMd),
          color: AdTheme.accent.withOpacity(0.12),
          border: Border.all(color: AdTheme.accent.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AdTheme.accent.withOpacity(0.15),
                border: Border.all(color: AdTheme.accent.withOpacity(0.3)),
              ),
              child: const Center(
                child: Icon(Icons.add, color: AdTheme.accent),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add New Wig', style: AdTheme.titleSm),
                  Text('Add a featured item to your catalog',
                      style: AdTheme.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AdTheme.accent),
          ],
        ),
      ),
    );
  }
}

// ── Add wig form (bottom sheet) ────────────────────────────────────────────
class _AddWigSheet extends StatefulWidget {
  const _AddWigSheet();

  @override
  State<_AddWigSheet> createState() => _AddWigSheetState();
}

class _AddWigSheetState extends State<_AddWigSheet> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl      = TextEditingController();
  final _stockCtrl     = TextEditingController();
  final _categoryCtrl  = TextEditingController();
  final _imageUrlCtrl  = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _stockCtrl.dispose();
    _categoryCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('wigs').add({
        'name':      _nameCtrl.text.trim(),
        'stock':     int.tryParse(_stockCtrl.text.trim()) ?? 0,
        'category':  _categoryCtrl.text.trim(),
        'imageUrl':  _imageUrlCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_nameCtrl.text.trim()} added to inventory ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add wig: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label, {String? hint}) {
    final radius = BorderRadius.circular(AdTheme.rSm);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: AdTheme.caption,
      filled: true,
      fillColor: AdTheme.cardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: AdTheme.accent.withOpacity(0.15))),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: AdTheme.accent.withOpacity(0.15))),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: AdTheme.accent, width: 1.4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: BoxDecoration(
          color: AdTheme.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AdTheme.rMd)),
          border: Border.all(color: AdTheme.accent.withOpacity(0.2)),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AdTheme.accent.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Text('Add New Wig', style: AdTheme.headingLg.copyWith(fontSize: 18)),
                const SizedBox(height: 4),
                Text('Add a new item to your inventory.', style: AdTheme.body.copyWith(fontSize: 12)),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameCtrl,
                  style: AdTheme.titleSm,
                  decoration: _decoration('Wig name', hint: 'e.g. Brazilian Body Wave'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stockCtrl,
                        style: AdTheme.titleSm,
                        keyboardType: TextInputType.number,
                        decoration: _decoration('Stock', hint: '0'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (int.tryParse(v.trim()) == null) return 'Number only';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _categoryCtrl,
                        style: AdTheme.titleSm,
                        decoration: _decoration('Category', hint: 'e.g. Lace Front'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _imageUrlCtrl,
                  style: AdTheme.titleSm,
                  decoration: _decoration('Image URL', hint: 'https://...'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdTheme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdTheme.rSm)),
                    ),
                    child: _saving
                        ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                        : Text('Save Wig',
                        style: AdTheme.label.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Orders today list ─────────────────────────────────────────────────────────
class _OrdersTodayList extends StatelessWidget {
  const _OrdersTodayList();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ShimmerList(count: 3);
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyState(
            emoji: '📦',
            message: 'No orders placed today yet.',
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final name   = d['customerName'] as String? ?? 'Customer';
              final amount = (d['totalAmount'] as num?)?.toDouble() ?? 0;
              final status = d['status'] as String? ?? 'pending';
              return _OrderTile(
                name: name,
                amount: amount,
                status: status,
                orderId: doc.id,
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _OrderTile extends StatelessWidget {
  final String name;
  final double amount;
  final String status;
  final String orderId;

  const _OrderTile({
    required this.name,
    required this.amount,
    required this.status,
    required this.orderId,
  });

  Color get _statusColor {
    switch (status) {
      case 'completed': return AdTheme.success;
      case 'cancelled': return AdTheme.error;
      case 'processing': return AdTheme.info;
      default:          return AdTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AdTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AdTheme.primary.withOpacity(0.12),
              border: Border.all(color: AdTheme.primary.withOpacity(0.3)),
            ),
            child: const Center(child: Text('📦', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AdTheme.titleSm),
                const SizedBox(height: 2),
                Text('#${orderId.substring(0, 6).toUpperCase()}',
                    style: AdTheme.caption),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('GH₵ ${amount.toStringAsFixed(0)}',
                  style: AdTheme.label.copyWith(fontSize: 13)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _statusColor.withOpacity(0.12),
                  border: Border.all(color: _statusColor.withOpacity(0.4)),
                ),
                child: Text(status,
                    style: TextStyle(
                        color: _statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Low stock list ────────────────────────────────────────────────────────────
class _LowStockList extends StatelessWidget {
  const _LowStockList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wigs')
          .where('stock', isLessThanOrEqualTo: 5)
          .orderBy('stock')
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ShimmerList(count: 3);
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyState(emoji: '✅', message: 'All items are well-stocked.');
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: docs.map((doc) {
              final d     = doc.data() as Map<String, dynamic>;
              final name  = d['name']     as String? ?? 'Wig';
              final stock = (d['stock']   as num?)?.toInt() ?? 0;
              final img   = d['imageUrl'] as String? ?? '';
              return _LowStockTile(name: name, stock: stock, imageUrl: img);
            }).toList(),
          ),
        );
      },
    );
  }
}

class _LowStockTile extends StatelessWidget {
  final String name;
  final int    stock;
  final String imageUrl;

  const _LowStockTile({
    required this.name,
    required this.stock,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isOut = stock == 0;
    final color = isOut ? AdTheme.error : AdTheme.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: AdTheme.cardDecoration(borderColor: color.withOpacity(0.3)),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(AdTheme.rSm),
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl, width: 44, height: 44, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _wigPlaceholder())
                : _wigPlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AdTheme.titleSm.copyWith(fontSize: 13)),
                const SizedBox(height: 3),
                Text(isOut ? 'Out of stock' : '$stock units left',
                    style: AdTheme.body.copyWith(color: color, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: color.withOpacity(0.12),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Text(isOut ? 'OUT' : 'LOW',
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _wigPlaceholder() => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AdTheme.rSm),
      color: AdTheme.primary.withOpacity(0.12),
    ),
    child: const Center(child: Text('👑', style: TextStyle(fontSize: 20))),
  );
}

// ── Shared shimmer + empty ────────────────────────────────────────────────────
class _ShimmerList extends StatefulWidget {
  final int count;
  const _ShimmerList({required this.count});

  @override
  State<_ShimmerList> createState() => _ShimmerListState();
}

class _ShimmerListState extends State<_ShimmerList>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
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
      builder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: List.generate(
            widget.count,
                (_) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              height: 68,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AdTheme.rMd),
                color: AdTheme.cardBg.withOpacity(_anim.value),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String emoji;
  final String message;
  const _EmptyState({required this.emoji, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: AdTheme.cardDecoration(),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(message, style: AdTheme.body),
          ],
        ),
      ),
    );
  }
}