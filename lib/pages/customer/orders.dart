import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tiwigsstrand/pages/customer/tw_theme.dart';

/// My Orders / Bookings Tab
/// Shows the logged-in customer's bookings from Firestore.
/// Collection: 'bookings' filtered by uid == currentUser.uid
class MyOrdersTab extends StatefulWidget {
  const MyOrdersTab({super.key});

  @override
  State<MyOrdersTab> createState() => _MyOrdersTabState();
}

class _MyOrdersTabState extends State<MyOrdersTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double>   _fade;

  String _filterStatus = 'All';
  static const List<String> _statuses = [
    'All', 'pending', 'confirmed', 'completed', 'cancelled'
  ];

  @override
  void initState() {
    super.initState();
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
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('bookings')
        .where('uid', isEqualTo: uid);
        
    if (_filterStatus != 'All') {
      q = q.where('status', isEqualTo: _filterStatus);
    }
    return q;
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MY BOOKINGS',
                      style: TwTheme.label.copyWith(fontSize: 10)),
                  const SizedBox(height: 4),
                  const Text('My Orders', style: TwTheme.displayMd),
                  const SizedBox(height: 2),
                  Text('Track your service bookings',
                      style: TwTheme.body.copyWith(fontSize: 12)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Status filter pills ──────────────────────────────────────────
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: _statuses.map((s) {
                  final active = _filterStatus == s;
                  return GestureDetector(
                    onTap: () => setState(() => _filterStatus = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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
                            color: TwTheme.primary.withOpacity(0.3),
                            blurRadius: 8)]
                            : [],
                      ),
                      child: Text(
                        s == 'All' ? 'All' : _capitalize(s),
                        style: TextStyle(
                          color: active ? Colors.white : TwTheme.textMid,
                          fontSize: 12,
                          fontWeight:
                          active ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // ── Bookings list ────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _query.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _OrdersSkeleton();
                  }
                  if (snapshot.hasError) {
                    return _OrdersError(
                        message: snapshot.error.toString());
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return _EmptyOrders(filter: _filterStatus);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const BouncingScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final d = docs[i].data() as Map<String, dynamic>;
                      return _OrderCard(data: d, index: i);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Order card ────────────────────────────────────────────────────────────────
class _OrderCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final int index;

  const _OrderCard({required this.data, required this.index});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _slide = Tween<Offset>(
        begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _statusColor {
    switch (widget.data['status'] as String? ?? 'pending') {
      case 'confirmed':  return const Color(0xFF4A90D9);
      case 'completed':  return TwTheme.success;
      case 'cancelled':  return TwTheme.error;
      default:           return TwTheme.error;
    }
  }

  String get _statusEmoji {
    switch (widget.data['status'] as String? ?? 'pending') {
      case 'confirmed':  return '✅';
      case 'completed':  return '🎉';
      case 'cancelled':  return '❌';
      default:           return '⏳';
    }
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return 'TBD';
    final dt = (ts as Timestamp).toDate();
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final hour   = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} · '
        '${hour.toString().padLeft(2, '0')}:$minute $period';
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

  @override
  Widget build(BuildContext context) {
    final service     = widget.data['service']     as String? ?? 'Service';
    final serviceType = widget.data['serviceType'] as String? ?? '';
    final price       = (widget.data['price'] as num?)?.toDouble() ?? 0;
    final status      = widget.data['status']      as String? ?? 'pending';
    final notes       = widget.data['notes']       as String? ?? '';
    final dateTime    = _formatDate(widget.data['dateTime']);
    final createdAt   = _formatDate(widget.data['createdAt']);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TwTheme.radiusMd),
              color: TwTheme.cardBg,
              border: Border.all(
                  color: _statusColor.withOpacity(0.25), width: 1),
              boxShadow: [
                BoxShadow(
                    color: _statusColor.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                // ── Main row ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // Service emoji circle
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: TwTheme.primary.withOpacity(0.12),
                          border: Border.all(
                              color: TwTheme.primary.withOpacity(0.3)),
                        ),
                        child: Center(
                          child: Text(_categoryEmoji(serviceType),
                              style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Service name + date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(service,
                                style: TwTheme.titleSm,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.calendar_today_outlined,
                                    color: TwTheme.textLow, size: 11),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(dateTime,
                                      style: TwTheme.caption
                                          .copyWith(fontSize: 10),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Price + status
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('GH₵ ${price.toStringAsFixed(0)}',
                              style: TwTheme.label.copyWith(fontSize: 13)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: _statusColor.withOpacity(0.12),
                              border: Border.all(
                                  color: _statusColor.withOpacity(0.4)),
                            ),
                            child: Text(
                              '$_statusEmoji ${_capitalize(status)}',
                              style: TextStyle(
                                  color: _statusColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),

                      // Expand chevron
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            color: TwTheme.textLow, size: 20),
                      ),
                    ],
                  ),
                ),

                // ── Expanded details ─────────────────────────────────────────
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: _ExpandedDetails(
                    data: widget.data,
                    notes: notes,
                    createdAt: createdAt,
                    serviceType: serviceType,
                  ),
                  crossFadeState: _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 280),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Expanded detail section ────────────────────────────────────────────────────
class _ExpandedDetails extends StatelessWidget {
  final Map<String, dynamic> data;
  final String notes;
  final String createdAt;
  final String serviceType;

  const _ExpandedDetails({
    required this.data,
    required this.notes,
    required this.createdAt,
    required this.serviceType,
  });

  @override
  Widget build(BuildContext context) {
    // Build service-specific detail rows
    final List<_DetailRow> rows = [];

    switch (serviceType) {
      case 'Wig Making':
        if ((data['hairType'] as String? ?? '').isNotEmpty)
          rows.add(_DetailRow('Hair Type', data['hairType']));
        if ((data['length'] as String? ?? '').isNotEmpty)
          rows.add(_DetailRow('Length', data['length']));
        if ((data['capSize'] as String? ?? '').isNotEmpty)
          rows.add(_DetailRow('Cap Size', data['capSize']));
        if ((data['wigType'] as String? ?? '').isNotEmpty)
          rows.add(_DetailRow('Wig Type', data['wigType']));
        break;
      case 'Revamping':
        if ((data['revampDetails'] as String? ?? '').isNotEmpty)
          rows.add(_DetailRow('Revamp Details', data['revampDetails']));
        break;
      case 'Styling':
        if ((data['stylingTechnique'] as String? ?? '').isNotEmpty)
          rows.add(_DetailRow('Technique', data['stylingTechnique']));
        break;
      case 'Factory Wig':
        if ((data['preferredColor'] as String? ?? '').isNotEmpty)
          rows.add(_DetailRow('Color', data['preferredColor']));
        break;
    }

    if (notes.isNotEmpty) rows.add(_DetailRow('Notes', notes));
    rows.add(_DetailRow('Booked on', createdAt));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: TwTheme.divider),
          const SizedBox(height: 12),
          ...rows.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 90,
                  child: Text(r.label,
                      style: TwTheme.caption
                          .copyWith(color: TwTheme.textLow, fontSize: 10)),
                ),
                Expanded(
                  child: Text(r.value,
                      style: TwTheme.body.copyWith(fontSize: 11)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _DetailRow {
  final String label;
  final dynamic value;
  _DetailRow(this.label, this.value);
}

// ── Empty state ────────────────────────────────────────────────────────────────
class _EmptyOrders extends StatelessWidget {
  final String filter;
  const _EmptyOrders({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TwTheme.primary.withOpacity(0.1),
                border: Border.all(color: TwTheme.primary.withOpacity(0.25)),
              ),
              child: const Center(
                  child: Text('📦', style: TextStyle(fontSize: 40))),
            ),
            const SizedBox(height: 20),
            Text(
              filter == 'All'
                  ? 'No bookings yet'
                  : 'No ${_capitalize(filter)} bookings',
              style: TwTheme.displayMd,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              filter == 'All'
                  ? 'Book a service and your orders\nwill appear here.'
                  : 'You have no $filter bookings at the moment.',
              textAlign: TextAlign.center,
              style: TwTheme.body,
            ),
          ],
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Error state ────────────────────────────────────────────────────────────────
class _OrdersError extends StatelessWidget {
  final String message;
  const _OrdersError({required this.message});

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
            const Text('Could not load orders', style: TwTheme.displayMd),
            const SizedBox(height: 8),
            Text(message,
                style: TwTheme.body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton loader ────────────────────────────────────────────────────────────
class _OrdersSkeleton extends StatefulWidget {
  const _OrdersSkeleton();

  @override
  State<_OrdersSkeleton> createState() => _OrdersSkeletonState();
}

class _OrdersSkeletonState extends State<_OrdersSkeleton>
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
      builder: (_, __) => ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          height: 82,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TwTheme.radiusMd),
            color: TwTheme.cardBg.withOpacity(_anim.value),
          ),
        ),
      ),
    );
  }
}