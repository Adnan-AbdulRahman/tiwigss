import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'ad_theme.dart';

/// Bookings Tab
/// Reads from Firestore collection: 'bookings'
/// Fields: { customerName, customerPhone, service, serviceType,
///           dateTime (Timestamp), status, notes, createdAt, uid }
class BookingsTab extends StatefulWidget {
  const BookingsTab({super.key});

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab>
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
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  Query<Map<String, dynamic>> get _query {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('bookings')
        .orderBy('createdAt', descending: true);
    if (_filterStatus != 'All') {
      q = q.where('status', isEqualTo: _filterStatus);
    }
    return q;
  }

  Future<void> _updateStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(docId)
        .update({'status': newStatus});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Booking marked as $newStatus'),
        backgroundColor: AdTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text('Bookings', style: AdTheme.headingLg),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text('Manage customer service bookings.', style: AdTheme.body),
          ),

          // ── Status filter pills ────────────────────────────────────────────
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: active ? AdTheme.primary : AdTheme.cardBg,
                      border: Border.all(
                        color: active ? AdTheme.primary : AdTheme.cardBorder,
                      ),
                    ),
                    child: Text(
                      s == 'All' ? 'All' : _capitalize(s),
                      style: TextStyle(
                        color: active ? Colors.white : AdTheme.textMid,
                        fontSize: 12,
                        fontWeight: active ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // ── Bookings list ──────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _BookingsSkeleton();
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: AdTheme.error)),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return _EmptyBookings(filter: _filterStatus);
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    return _BookingCard(
                      docId: docs[i].id,
                      data: d,
                      onUpdateStatus: _updateStatus,
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

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Booking card ──────────────────────────────────────────────────────────────
class _BookingCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final Future<void> Function(String docId, String status) onUpdateStatus;

  const _BookingCard({
    required this.docId,
    required this.data,
    required this.onUpdateStatus,
  });

  Color get _statusColor {
    switch (data['status'] as String? ?? 'pending') {
      case 'confirmed':  return AdTheme.info;
      case 'completed':  return AdTheme.success;
      case 'cancelled':  return AdTheme.error;
      default:           return AdTheme.warning;
    }
  }

  String get _statusLabel {
    final s = data['status'] as String? ?? 'pending';
    return s[0].toUpperCase() + s.substring(1);
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return 'Date TBD';
    final dt = (ts as Timestamp).toDate();
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final customerName  = data['customerName']  as String? ?? 'Customer';
    final customerPhone = data['customerPhone'] as String? ?? '-';
    final service       = data['service']       as String? ?? 'Service';
    final serviceType   = data['serviceType']   as String? ?? '';
    final notes         = data['notes']         as String? ?? '';
    final bookingDate   = _formatDate(data['dateTime']);
    final status        = data['status'] as String? ?? 'pending';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AdTheme.cardDecoration(borderColor: _statusColor.withOpacity(0.25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AdTheme.primary.withOpacity(0.12),
                  border: Border.all(color: AdTheme.primary.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(_serviceEmoji(serviceType),
                      style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customerName, style: AdTheme.titleSm),
                    const SizedBox(height: 2),
                    Text(customerPhone,
                        style: AdTheme.caption.copyWith(color: AdTheme.textMid)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _statusColor.withOpacity(0.12),
                  border: Border.all(color: _statusColor.withOpacity(0.4)),
                ),
                child: Text(_statusLabel,
                    style: TextStyle(
                        color: _statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Container(height: 1, color: AdTheme.cardBorder),
          const SizedBox(height: 12),

          // Service + date
          _infoRow(Icons.content_cut_rounded, service),
          const SizedBox(height: 6),
          _infoRow(Icons.calendar_today_outlined, bookingDate),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            _infoRow(Icons.notes_rounded, notes),
          ],

          const SizedBox(height: 14),

          // Action buttons
          if (status == 'pending')
            Row(
              children: [
                Expanded(
                  child: _ActionBtn(
                    label: 'Confirm',
                    color: AdTheme.info,
                    onTap: () => onUpdateStatus(docId, 'confirmed'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionBtn(
                    label: 'Cancel',
                    color: AdTheme.error,
                    onTap: () => onUpdateStatus(docId, 'cancelled'),
                  ),
                ),
              ],
            ),
          if (status == 'confirmed')
            _ActionBtn(
              label: 'Mark as Completed',
              color: AdTheme.success,
              fullWidth: true,
              onTap: () => onUpdateStatus(docId, 'completed'),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Row(
        children: [
          Icon(icon, color: AdTheme.textLow, size: 14),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AdTheme.body.copyWith(fontSize: 12))),
        ],
      );

  String _serviceEmoji(String type) {
    switch (type) {
      case 'Wig Making':  return '🪡';
      case 'Revamping':   return '✨';
      case 'Styling':     return '💇‍♀️';
      case 'Factory Wig': return '🏭';
      default:            return '👑';
    }
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool fullWidth;

  const _ActionBtn({
    required this.label,
    required this.color,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AdTheme.rSm),
          color: color.withOpacity(0.12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ),
    );
    return btn;
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyBookings extends StatelessWidget {
  final String filter;
  const _EmptyBookings({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📅', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              filter == 'All'
                  ? 'No bookings yet'
                  : 'No ${filter} bookings',
              style: AdTheme.headingMd,
            ),
            const SizedBox(height: 8),
            Text(
              'When customers book services, they\'ll appear here.',
              textAlign: TextAlign.center,
              style: AdTheme.body,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton loader ───────────────────────────────────────────────────────────
class _BookingsSkeleton extends StatefulWidget {
  const _BookingsSkeleton();

  @override
  State<_BookingsSkeleton> createState() => _BookingsSkeletonState();
}

class _BookingsSkeletonState extends State<_BookingsSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

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
      builder: (_, __) => ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          height: 130,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AdTheme.rMd),
            color: AdTheme.cardBg.withOpacity(_anim.value),
          ),
        ),
      ),
    );
  }
}
