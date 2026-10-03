import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tiwigsstrand/pages/customer/tw_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  RECEIPTS PAGE  (manual receipts)
//  • You type every detail yourself (no bookings involved)
//  • Receipts are saved in Firestore collection: 'receipts'
//  • Every saved receipt appears in the list below
//  • Tap a receipt → full receipt template → Download / Share / Edit / Delete
// ─────────────────────────────────────────────────────────────────────────────

const _kStatuses = ['pending', 'confirmed', 'completed', 'cancelled'];
const _kWigTypes = [
  'None',
  'Frontal',
  'Closure',
  'Full Lace',
  '360 Lace',
  'Glueless',
  'Other'
];
const _kPayMethods = ['Cash', 'MoMo', 'Card', 'Bank Transfer'];

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

CollectionReference<Map<String, dynamic>> get _receiptsCol =>
    FirebaseFirestore.instance.collection('receipts');

Color _statusColorOf(String status) {
  switch (status) {
    case 'completed':
      return const Color(0xFF4CAF7D);
    case 'confirmed':
      return const Color(0xFF4A90D9);
    case 'cancelled':
      return const Color(0xFFE05C72);
    default:
      return const Color(0xFFE8A838);
  }
}

class Receipts extends StatefulWidget {
  const Receipts({super.key});

  @override
  State<Receipts> createState() => _ReceiptsState();
}

class _ReceiptsState extends State<Receipts>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  String _filter = 'All';
  static const _filters = ['All', ..._kStatuses];

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

  // No orderBy / second where → no Firestore composite index needed.
  // Filtering and sorting are done on the device.
  Query<Map<String, dynamic>> get _query {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return _receiptsCol.where('uid', isEqualTo: uid);
  }

  void _openCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReceiptFormPage()),
    );
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RECEIPTS',
                            style: TwTheme.label.copyWith(fontSize: 10)),
                        const SizedBox(height: 4),
                        const Text('My Receipts', style: TwTheme.displayMd),
                        const SizedBox(height: 2),
                        Text('Create, download or share receipts',
                            style: TwTheme.body.copyWith(fontSize: 12)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _openCreate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: TwTheme.primary,
                        boxShadow: [
                          BoxShadow(
                              color: TwTheme.primary.withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 4),
                        Text('New',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Filter pills ─────────────────────────────────────────────────
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: _filters.map((f) {
                  final active = _filter == f;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f),
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
                            ? [
                          BoxShadow(
                              color: TwTheme.primary.withOpacity(0.3),
                              blurRadius: 8)
                        ]
                            : [],
                      ),
                      child: Text(
                        _cap(f),
                        style: TextStyle(
                          color: active ? Colors.white : TwTheme.textMid,
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

            // ── Receipts list ────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _query.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _ReceiptsSkeleton();
                  }
                  if (snapshot.hasError) {
                    return _ErrorState(message: snapshot.error.toString());
                  }

                  var docs = [...(snapshot.data?.docs ?? [])];

                  // newest first
                  docs.sort((a, b) {
                    final ta = a.data()['createdAt'];
                    final tb = b.data()['createdAt'];
                    final da = ta is Timestamp
                        ? ta.millisecondsSinceEpoch
                        : 0;
                    final db = tb is Timestamp
                        ? tb.millisecondsSinceEpoch
                        : 0;
                    return db.compareTo(da);
                  });

                  if (_filter != 'All') {
                    docs = docs
                        .where((d) => (d.data()['status'] ?? 'pending') == _filter)
                        .toList();
                  }

                  if (docs.isEmpty) {
                    return _EmptyReceipts(filter: _filter, onCreate: _openCreate);
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    physics: const BouncingScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, i) {
                      return _ReceiptCard(
                        data: docs[i].data(),
                        receiptId: docs[i].id,
                        index: i,
                      );
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
}

// ─────────────────────────────────────────────────────────────────────────────
//  RECEIPT CARD  (collapsed list tile — tap to open full receipt)
// ─────────────────────────────────────────────────────────────────────────────
class _ReceiptCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String receiptId;
  final int index;

  const _ReceiptCard({
    required this.data,
    required this.receiptId,
    required this.index,
  });

  @override
  State<_ReceiptCard> createState() => _ReceiptCardState();
}

class _ReceiptCardState extends State<_ReceiptCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: 60 * widget.index.clamp(0, 10)), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _status => widget.data['status'] as String? ?? 'pending';
  Color get _statusColor => _statusColorOf(_status);

  String _formatDate(dynamic ts) {
    if (ts is! Timestamp) return '--';
    final dt = ts.toDate();
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.data['service'] as String? ?? 'Service';
    final custName = widget.data['customerName'] as String? ?? '';
    final price = (widget.data['price'] as num?)?.toDouble() ?? 0;
    final discount = (widget.data['discount'] as num?)?.toDouble() ?? 0;
    final total = (price - discount).clamp(0, double.infinity);
    final date = _formatDate(widget.data['createdAt']);
    final inches = widget.data['length'] as String? ??
        widget.data['capSize'] as String? ??
        '';

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) =>
                  ReceiptDetailPage(receiptId: widget.receiptId),
              transitionsBuilder: (_, anim, __, child) => SlideTransition(
                position: Tween<Offset>(
                    begin: const Offset(0, 1), end: Offset.zero)
                    .animate(CurvedAnimation(
                    parent: anim, curve: Curves.easeOutCubic)),
                child: child,
              ),
              transitionDuration: const Duration(milliseconds: 380),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TwTheme.radiusMd),
              color: TwTheme.cardBg,
              border:
              Border.all(color: _statusColor.withOpacity(0.22), width: 1),
              boxShadow: [
                BoxShadow(
                    color: _statusColor.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TwTheme.primary.withOpacity(0.12),
                    border: Border.all(color: TwTheme.primary.withOpacity(0.3)),
                  ),
                  child: const Center(
                      child: Text('🧾', style: TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(custName.isEmpty ? service : custName,
                          style: TwTheme.titleSm.copyWith(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      if (custName.isNotEmpty)
                        Text(service,
                            style: TwTheme.caption.copyWith(
                                fontSize: 11, color: TwTheme.textMid),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(
                          'Receipt #${widget.receiptId.substring(0, 8).toUpperCase()}',
                          style: TwTheme.caption.copyWith(fontSize: 10)),
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.calendar_today_outlined,
                            color: TwTheme.textLow, size: 10),
                        const SizedBox(width: 4),
                        Text(date,
                            style: TwTheme.caption.copyWith(
                                fontSize: 10, color: TwTheme.textMid)),
                        if (inches.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          const Text('·',
                              style: TextStyle(
                                  color: TwTheme.textLow, fontSize: 10)),
                          const SizedBox(width: 8),
                          const Icon(Icons.straighten_rounded,
                              color: TwTheme.textLow, size: 10),
                          const SizedBox(width: 4),
                          Text(inches,
                              style: TwTheme.caption.copyWith(
                                  fontSize: 10, color: TwTheme.textMid)),
                        ],
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('GH₵ ${total.toStringAsFixed(0)}',
                        style: TwTheme.label.copyWith(fontSize: 14)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: _statusColor.withOpacity(0.12),
                        border:
                        Border.all(color: _statusColor.withOpacity(0.4)),
                      ),
                      child: Text(_cap(_status),
                          style: TextStyle(
                              color: _statusColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text('View',
                          style: TwTheme.label
                              .copyWith(fontSize: 10, color: TwTheme.accent)),
                      const SizedBox(width: 3),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: TwTheme.accent, size: 10),
                    ]),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CREATE / EDIT RECEIPT FORM  (you type everything here)
// ─────────────────────────────────────────────────────────────────────────────
class ReceiptFormPage extends StatefulWidget {
  /// null → create a new receipt. Otherwise edit this receipt.
  final String? receiptId;
  final Map<String, dynamic>? existing;

  const ReceiptFormPage({super.key, this.receiptId, this.existing});

  @override
  State<ReceiptFormPage> createState() => _ReceiptFormPageState();
}

class _ReceiptFormPageState extends State<ReceiptFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _custName = TextEditingController();
  final _custPhone = TextEditingController();
  final _service = TextEditingController();
  final _category = TextEditingController();
  final _length = TextEditingController();
  final _hairType = TextEditingController();
  final _capSize = TextEditingController();
  final _density = TextEditingController();
  final _color = TextEditingController();
  final _notes = TextEditingController();
  final _price = TextEditingController();
  final _discount = TextEditingController();
  final _paid = TextEditingController();

  String _status = 'pending';
  String _wigType = 'None';
  String _payMethod = '';
  DateTime? _appointment;
  bool _saving = false;

  bool get _isEdit => widget.receiptId != null;

  @override
  void initState() {
    super.initState();
    final d = widget.existing;
    if (d != null) {
      _custName.text = d['customerName'] as String? ?? '';
      _custPhone.text = d['customerPhone'] as String? ?? '';
      _service.text = d['service'] as String? ?? '';
      _category.text = d['serviceType'] as String? ?? '';
      _length.text = d['length'] as String? ?? '';
      _hairType.text = d['hairType'] as String? ?? '';
      _capSize.text = d['capSize'] as String? ?? '';
      _density.text = d['density'] as String? ?? '';
      _color.text = d['color'] as String? ?? '';
      _notes.text = d['notes'] as String? ?? '';
      _price.text = _numText(d['price']);
      _discount.text = _numText(d['discount']);
      _paid.text = _numText(d['amountPaid']);
      _status = d['status'] as String? ?? 'pending';
      _wigType = d['wigType'] as String? ?? 'None';
      if (_wigType.isEmpty) _wigType = 'None';
      _payMethod = d['paymentMethod'] as String? ?? '';
      final ts = d['dateTime'];
      if (ts is Timestamp) _appointment = ts.toDate();
    }
  }

  String _numText(dynamic v) {
    if (v is! num || v == 0) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  @override
  void dispose() {
    for (final c in [
      _custName, _custPhone, _service, _category, _length, _hairType,
      _capSize, _density, _color, _notes, _price, _discount, _paid
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double _parse(String s) =>
      double.tryParse(s.replaceAll(',', '').trim()) ?? 0;

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _appointment ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_appointment ?? now),
    );
    if (time == null) return;
    setState(() {
      _appointment =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String _prettyAppointment() {
    final dt = _appointment;
    if (dt == null) return 'Tap to pick date & time (optional)';
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}  $hour:$minute $period';
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final price = _parse(_price.text);
    final discount = _parse(_discount.text);
    if (discount > price) {
      _snack('Discount cannot be more than the price');
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final payload = <String, dynamic>{
        'uid': uid,
        'customerName': _custName.text.trim(),
        'customerPhone': _custPhone.text.trim(),
        'service': _service.text.trim(),
        'serviceType': _category.text.trim(),
        'dateTime':
        _appointment == null ? null : Timestamp.fromDate(_appointment!),
        'length': _length.text.trim(),
        'hairType': _hairType.text.trim(),
        'capSize': _capSize.text.trim(),
        'wigType': _wigType == 'None' ? '' : _wigType,
        'density': _density.text.trim(),
        'color': _color.text.trim(),
        'notes': _notes.text.trim(),
        'price': price,
        'discount': discount,
        'amountPaid': _parse(_paid.text),
        'paymentMethod': _payMethod,
        'status': _status,
        'updatedAt': Timestamp.now(),
      };

      if (_isEdit) {
        await _receiptsCol.doc(widget.receiptId).update(payload);
        if (mounted) Navigator.pop(context);
      } else {
        payload['createdAt'] = Timestamp.now();
        final ref = await _receiptsCol.add(payload);
        if (!mounted) return;
        // Replace the form with the finished receipt
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => ReceiptDetailPage(receiptId: ref.id)),
        );
      }
    } catch (e) {
      if (mounted) _snack('Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: TwTheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Small UI helpers ───────────────────────────────────────────────────────
  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Text(t.toUpperCase(),
        style: TwTheme.label.copyWith(fontSize: 11, letterSpacing: 1.2)),
  );

  Widget _field(
      String label,
      TextEditingController c, {
        String? hint,
        TextInputType? type,
        bool required = false,
        int maxLines = 1,
        String? prefix,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
        decoration: InputDecoration(
          labelText: label + (required ? ' *' : ''),
          hintText: hint,
          prefixText: prefix,
          prefixStyle: const TextStyle(color: Colors.white),
          labelStyle: TextStyle(color: TwTheme.textMid, fontSize: 13),
          hintStyle: TextStyle(color: TwTheme.textLow, fontSize: 13),
          filled: true,
          fillColor: TwTheme.cardBg,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(TwTheme.radiusMd),
            borderSide: BorderSide(color: TwTheme.primary.withOpacity(0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(TwTheme.radiusMd),
            borderSide: BorderSide(color: TwTheme.primary.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(TwTheme.radiusMd),
            borderSide: const BorderSide(color: TwTheme.primary, width: 1.4),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(TwTheme.radiusMd),
            borderSide: const BorderSide(color: TwTheme.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(TwTheme.radiusMd),
            borderSide: const BorderSide(color: TwTheme.error, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _chips(List<String> options, String selected, ValueChanged<String> onTap,
      {bool colored = false}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final active = selected == o;
        final c = colored ? _statusColorOf(o) : TwTheme.primary;
        return GestureDetector(
          onTap: () => onTap(o),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: active ? c : TwTheme.cardBg,
              border: Border.all(color: active ? c : c.withOpacity(0.3)),
            ),
            child: Text(
              _cap(o),
              style: TextStyle(
                color: active ? Colors.white : TwTheme.textMid,
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwTheme.darkBg,
      body: Container(
        decoration: const BoxDecoration(gradient: TwTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: TwTheme.cardBg,
                        border:
                        Border.all(color: TwTheme.primary.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: TwTheme.textMid, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(_isEdit ? 'Edit Receipt' : 'New Receipt',
                        style: TwTheme.displayMd),
                  ),
                ]),
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                    children: [
                      _section('Customer'),
                      _field('Customer name', _custName, required: true),
                      _field('Phone number', _custPhone,
                          type: TextInputType.phone, hint: '024 000 0000'),

                      _section('Service'),
                      _field('Service', _service,
                          required: true, hint: 'e.g. Frontal wig install'),
                      _field('Category', _category,
                          hint: 'e.g. Wig Making, Revamping, Styling'),
                      GestureDetector(
                        onTap: _pickDateTime,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 15),
                          decoration: BoxDecoration(
                            color: TwTheme.cardBg,
                            borderRadius:
                            BorderRadius.circular(TwTheme.radiusMd),
                            border: Border.all(
                                color: TwTheme.primary.withOpacity(0.2)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.event_rounded,
                                color: TwTheme.accent, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_prettyAppointment(),
                                  style: TextStyle(
                                      color: _appointment == null
                                          ? TwTheme.textLow
                                          : Colors.white,
                                      fontSize: 13)),
                            ),
                            if (_appointment != null)
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _appointment = null),
                                child: const Icon(Icons.close_rounded,
                                    color: TwTheme.textMid, size: 18),
                              ),
                          ]),
                        ),
                      ),

                      _section('Wig specifications (optional)'),
                      Row(children: [
                        Expanded(
                            child: _field('Length', _length, hint: 'e.g. 24"')),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _field('Cap size', _capSize,
                                hint: 'e.g. Medium')),
                      ]),
                      _field('Hair type', _hairType,
                          hint: 'e.g. Bone straight, Curly'),
                      Row(children: [
                        Expanded(
                            child:
                            _field('Density', _density, hint: 'e.g. 180%')),
                        const SizedBox(width: 12),
                        Expanded(child: _field('Color', _color, hint: 'e.g. 1B')),
                      ]),
                      Text('Wig type',
                          style: TextStyle(color: TwTheme.textMid, fontSize: 12)),
                      const SizedBox(height: 8),
                      _chips(_kWigTypes, _wigType,
                              (v) => setState(() => _wigType = v)),

                      _section('Payment'),
                      Row(children: [
                        Expanded(
                            child: _field('Price', _price,
                                required: true,
                                prefix: 'GH₵ ',
                                type: const TextInputType.numberWithOptions(
                                    decimal: true))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _field('Discount', _discount,
                                prefix: 'GH₵ ',
                                type: const TextInputType.numberWithOptions(
                                    decimal: true))),
                      ]),
                      _field('Amount paid (deposit)', _paid,
                          prefix: 'GH₵ ',
                          type: const TextInputType.numberWithOptions(
                              decimal: true)),
                      Text('Payment method',
                          style: TextStyle(color: TwTheme.textMid, fontSize: 12)),
                      const SizedBox(height: 8),
                      _chips(
                          _kPayMethods,
                          _payMethod,
                              (v) => setState(
                                  () => _payMethod = _payMethod == v ? '' : v)),

                      _section('Status'),
                      _chips(_kStatuses, _status,
                              (v) => setState(() => _status = v),
                          colored: true),

                      _section('Notes'),
                      _field('Notes (optional)', _notes, maxLines: 3),

                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _saving ? null : _save,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            borderRadius:
                            BorderRadius.circular(TwTheme.radiusMd),
                            color: TwTheme.primary,
                            boxShadow: [
                              BoxShadow(
                                  color: TwTheme.primary.withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Center(
                            child: _saving
                                ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                                : Text(
                                _isEdit ? 'Save Changes' : 'Create Receipt',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  RECEIPT DETAIL PAGE  (full receipt + download + share + edit + delete)
// ─────────────────────────────────────────────────────────────────────────────
class ReceiptDetailPage extends StatefulWidget {
  final String receiptId;

  const ReceiptDetailPage({super.key, required this.receiptId});

  @override
  State<ReceiptDetailPage> createState() => _ReceiptDetailPageState();
}

class _ReceiptDetailPageState extends State<ReceiptDetailPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  final GlobalKey _receiptKey = GlobalKey();

  bool _downloading = false;
  bool _sharing = false;

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

  Future<Uint8List?> _captureReceipt() async {
    try {
      final boundary = _receiptKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Capture error: $e');
      return null;
    }
  }

  Future<void> _downloadReceipt() async {
    setState(() => _downloading = true);
    try {
      final bytes = await _captureReceipt();
      if (bytes == null) throw Exception('Could not capture receipt');

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/receipt_${widget.receiptId.substring(0, 8)}.png');
      await file.writeAsBytes(bytes);

      if (mounted) _showSnack('Receipt saved to your device! 📥', isSuccess: true);
    } catch (e) {
      if (mounted) _showSnack('Download failed: $e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _shareReceipt() async {
    setState(() => _sharing = true);
    try {
      final bytes = await _captureReceipt();
      if (bytes == null) throw Exception('Could not capture receipt');

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/receipt_${widget.receiptId.substring(0, 8)}.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'My Tiwigsstrand Receipt 👑',
        subject: 'Tiwigsstrand Booking Receipt',
      );
    } catch (e) {
      if (mounted) _showSnack('Share failed: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _deleteReceipt() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TwTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete receipt?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text('This cannot be undone.',
            style: TextStyle(color: TwTheme.textMid, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: TwTheme.textMid))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: TwTheme.error))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _receiptsCol.doc(widget.receiptId).delete();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showSnack('Delete failed: $e');
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
            isSuccess
                ? Icons.check_circle_rounded
                : Icons.error_outline_rounded,
            color: Colors.white,
            size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: isSuccess ? TwTheme.success : TwTheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Widget _circleBtn(IconData icon, Color color, VoidCallback? onTap,
      {bool loading = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: TwTheme.cardBg,
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: loading
            ? Padding(
            padding: const EdgeInsets.all(12),
            child: CircularProgressIndicator(strokeWidth: 2, color: color))
            : Icon(icon, color: color, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwTheme.darkBg,
      body: Container(
        decoration: const BoxDecoration(gradient: TwTheme.bgGradient),
        child: FadeTransition(
          opacity: _fade,
          child: SafeArea(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _receiptsCol.doc(widget.receiptId).snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(color: TwTheme.primary));
                }
                if (snap.hasError) {
                  return _ErrorState(message: snap.error.toString());
                }
                final data = snap.data?.data();
                if (data == null) {
                  return const Center(
                      child: Text('Receipt not found', style: TwTheme.body));
                }

                return Column(
                  children: [
                    // ── App bar ────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Row(
                        children: [
                          _circleBtn(Icons.arrow_back_ios_new_rounded,
                              TwTheme.textMid, () => Navigator.pop(context)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Receipt', style: TwTheme.displayMd),
                                Text(
                                    '#${widget.receiptId.substring(0, 8).toUpperCase()}',
                                    style: TwTheme.body.copyWith(
                                        color: TwTheme.accent, fontSize: 11)),
                              ],
                            ),
                          ),
                          _circleBtn(
                            Icons.edit_rounded,
                            TwTheme.primary,
                                () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReceiptFormPage(
                                  receiptId: widget.receiptId,
                                  existing: data,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _circleBtn(Icons.delete_outline_rounded, TwTheme.error,
                              _deleteReceipt),
                          const SizedBox(width: 8),
                          _circleBtn(Icons.share_rounded, TwTheme.accent,
                              _sharing ? null : _shareReceipt,
                              loading: _sharing),
                        ],
                      ),
                    ),

                    // ── Receipt content ────────────────────────────────────
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          children: [
                            RepaintBoundary(
                              key: _receiptKey,
                              child: _ReceiptWidget(
                                data: data,
                                receiptId: widget.receiptId,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(children: [
                              Expanded(
                                child: _ActionBtn(
                                  icon: Icons.download_rounded,
                                  label: 'Download',
                                  subtitle: 'Save to device',
                                  color: TwTheme.primary,
                                  isLoading: _downloading,
                                  onTap: _downloadReceipt,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ActionBtn(
                                  icon: Icons.share_rounded,
                                  label: 'Share',
                                  subtitle: 'Send to others',
                                  color: const Color(0xFF4A90D9),
                                  isLoading: _sharing,
                                  onTap: _shareReceipt,
                                ),
                              ),
                            ]),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius:
                                BorderRadius.circular(TwTheme.radiusMd),
                                color: TwTheme.accent.withOpacity(0.06),
                                border: Border.all(
                                    color: TwTheme.accent.withOpacity(0.2)),
                              ),
                              child: Row(children: [
                                const Text('💡', style: TextStyle(fontSize: 14)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'You can also screenshot this receipt directly on your phone.',
                                    style: TwTheme.body.copyWith(fontSize: 11),
                                  ),
                                ),
                              ]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  RECEIPT WIDGET  (the actual printable receipt template)
// ─────────────────────────────────────────────────────────────────────────────
class _ReceiptWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  final String receiptId;

  const _ReceiptWidget({required this.data, required this.receiptId});

  String _formatDate(dynamic ts) {
    if (ts is! Timestamp) return '--';
    final dt = ts.toDate();
    const m = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}  $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final service = data['service'] as String? ?? 'Service';
    final serviceType = data['serviceType'] as String? ?? '';
    final price = (data['price'] as num?)?.toDouble() ?? 0;
    final discount = (data['discount'] as num?)?.toDouble() ?? 0;
    final paid = (data['amountPaid'] as num?)?.toDouble() ?? 0;
    final payMethod = data['paymentMethod'] as String? ?? '';
    final total = (price - discount).clamp(0, double.infinity).toDouble();
    final balance = (total - paid).clamp(0, double.infinity).toDouble();
    final custName = data['customerName'] as String? ?? '--';
    final custPhone = data['customerPhone'] as String? ?? '';
    final notes = data['notes'] as String? ?? '';
    final status = data['status'] as String? ?? 'pending';
    final hasAppointment = data['dateTime'] is Timestamp;
    final dateTime = _formatDate(data['dateTime']);
    final createdAt = _formatDate(data['createdAt']);
    final length = data['length'] as String? ?? '';
    final hairType = data['hairType'] as String? ?? '';
    final capSize = data['capSize'] as String? ?? '';
    final wigType = data['wigType'] as String? ?? '';
    final density = data['density'] as String? ?? '';
    final color = data['color'] as String? ?? '';
    final statusColor = _statusColorOf(status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF8B1A4A).withOpacity(0.2),
              blurRadius: 24,
              offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // ── Header band ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8B1A4A), Color(0xFF5C0F30)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.15),
                          border:
                          Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logoo.jpeg',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                                child:
                                Text('👑', style: TextStyle(fontSize: 22))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: const TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Tiwigs',
                                  style: TextStyle(
                                    color: Color(0xFFD4A853),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                TextSpan(
                                  text: 'strand',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            'Wig Making · Revamping · Styling',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Column(children: [
                      _shopInfoRow(Icons.location_on_rounded,
                          'Accra, UPSA Main Branch'),
                      const SizedBox(height: 6),
                      _shopInfoRow(Icons.phone_rounded, '+233598384089'),
                      const SizedBox(height: 6),
                      _shopInfoRow(
                          Icons.email_rounded, 'braidsonbeauty@gmail.com'),
                      const SizedBox(height: 6),
                      _shopInfoRow(
                          Icons.language_rounded, 'tiwigsstrand.web.app'),
                      const SizedBox(height: 6),
                      _shopInfoRow(Icons.camera_alt_rounded, '@tiwigsstrand'),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4A853),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'RECEIPT',
                      style: TextStyle(
                        color: Color(0xFF5C0F30),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            _ZigZag(color: Colors.white),

            // ── Receipt body ──────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReceiptRow(
                    label: 'Receipt No.',
                    value: '#${receiptId.substring(0, 8).toUpperCase()}',
                    valueStyle: const TextStyle(
                        color: Color(0xFF8B1A4A),
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                  _ReceiptRow(label: 'Issued On', value: createdAt),

                  _Divider(),

                  _SectionTitle(title: 'Customer Details'),
                  _ReceiptRow(label: 'Name', value: custName),
                  if (custPhone.isNotEmpty)
                    _ReceiptRow(label: 'Phone', value: custPhone),

                  _Divider(),

                  _SectionTitle(title: 'Service Details'),
                  _ReceiptRow(label: 'Service', value: service),
                  if (serviceType.isNotEmpty)
                    _ReceiptRow(label: 'Category', value: serviceType),
                  if (hasAppointment)
                    _ReceiptRow(label: 'Appointment', value: dateTime),

                  _Divider(),

                  if ([length, hairType, capSize, wigType, density, color]
                      .any((s) => s.isNotEmpty)) ...[
                    _SectionTitle(title: 'Wig Specifications'),
                    if (length.isNotEmpty)
                      _ReceiptRow(label: 'Length', value: length),
                    if (hairType.isNotEmpty)
                      _ReceiptRow(label: 'Hair Type', value: hairType),
                    if (capSize.isNotEmpty)
                      _ReceiptRow(label: 'Cap Size', value: capSize),
                    if (wigType.isNotEmpty && wigType != 'None')
                      _ReceiptRow(label: 'Wig Type', value: wigType),
                    if (density.isNotEmpty)
                      _ReceiptRow(label: 'Density', value: density),
                    if (color.isNotEmpty)
                      _ReceiptRow(label: 'Color', value: color),
                    _Divider(),
                  ],

                  if (notes.isNotEmpty) ...[
                    _SectionTitle(title: 'Notes'),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(notes,
                          style: const TextStyle(
                              color: Color(0xFF555555),
                              fontSize: 12,
                              height: 1.5)),
                    ),
                    _Divider(),
                  ],

                  // Payment
                  _SectionTitle(title: 'Payment Summary'),
                  _ReceiptRow(
                      label: 'Service Fee',
                      value: 'GH₵ ${price.toStringAsFixed(2)}'),
                  _ReceiptRow(
                      label: 'Discount',
                      value: 'GH₵ ${discount.toStringAsFixed(2)}'),
                  if (payMethod.isNotEmpty)
                    _ReceiptRow(label: 'Paid Via', value: payMethod),
                  const SizedBox(height: 6),

                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B1A4A).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF8B1A4A).withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL AMOUNT',
                            style: TextStyle(
                              color: Color(0xFF8B1A4A),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            )),
                        Text('GH₵ ${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF8B1A4A),
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            )),
                      ],
                    ),
                  ),

                  if (paid > 0) ...[
                    const SizedBox(height: 10),
                    _ReceiptRow(
                        label: 'Amount Paid',
                        value: 'GH₵ ${paid.toStringAsFixed(2)}'),
                    _ReceiptRow(
                      label: 'Balance',
                      value: 'GH₵ ${balance.toStringAsFixed(2)}',
                      valueStyle: TextStyle(
                          color: balance > 0
                              ? const Color(0xFFE05C72)
                              : const Color(0xFF4CAF7D),
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ],

                  const SizedBox(height: 16),

                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.4)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_statusIcon(status), color: statusColor, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          _cap(status),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 20),
                  _Divider(dashed: true),
                  const SizedBox(height: 14),

                  Center(
                    child: Column(children: [
                      const Text('👑', style: TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      const Text(
                        'Thank you for choosing Tiwigsstrand!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF8B1A4A),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Your beauty is our passion. We look\nforward to serving you again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'This is a digital receipt. Keep it for your records.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 9,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shopInfoRow(IconData icon, String text) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, color: Colors.white60, size: 12),
      const SizedBox(width: 6),
      Text(text,
          style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
    ],
  );

  IconData _statusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle_rounded;
      case 'confirmed':
        return Icons.verified_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }
}

// ── ZigZag edge between header and body ──────────────────────────────────────
class _ZigZag extends StatelessWidget {
  final Color color;
  const _ZigZag({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 16),
      painter: _ZigZagPainter(color: color),
    );
  }
}

class _ZigZagPainter extends CustomPainter {
  final Color color;
  const _ZigZagPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    const w = 16.0;
    path.moveTo(0, size.height);
    double x = 0;
    bool up = true;
    while (x <= size.width) {
      x += w;
      path.lineTo(x, up ? 0 : size.height);
      up = !up;
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Shared receipt widgets ────────────────────────────────────────────────────
class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;
  const _ReceiptRow(
      {required this.label, required this.value, this.valueStyle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: valueStyle ??
                    const TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title.toUpperCase(),
          style: const TextStyle(
              color: Color(0xFF8B1A4A),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2)),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool dashed;
  const _Divider({this.dashed = false});

  @override
  Widget build(BuildContext context) {
    if (!dashed) {
      return Container(
          height: 1,
          color: const Color(0xFFEEEEEE),
          margin: const EdgeInsets.only(bottom: 12, top: 4));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: List.generate(
          30,
              (i) => Expanded(
            child: Container(
              height: 1,
              color: i.isEven ? Colors.transparent : const Color(0xFFCCCCCC),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────
class _ActionBtn extends StatefulWidget {
  final IconData icon;
  final String label, subtitle;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        if (!widget.isLoading) widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TwTheme.radiusMd),
            color: widget.color.withOpacity(0.1),
            border: Border.all(color: widget.color.withOpacity(0.35)),
          ),
          child: widget.isLoading
              ? Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: widget.color),
            ),
          )
              : Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.icon, color: widget.color, size: 22),
            const SizedBox(height: 5),
            Text(widget.label,
                style: TextStyle(
                    color: widget.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            Text(widget.subtitle,
                style: TwTheme.caption.copyWith(fontSize: 10)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  EMPTY + SKELETON + ERROR STATES
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyReceipts extends StatelessWidget {
  final String filter;
  final VoidCallback onCreate;
  const _EmptyReceipts({required this.filter, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TwTheme.primary.withOpacity(0.1),
              border: Border.all(color: TwTheme.primary.withOpacity(0.25)),
            ),
            child: const Center(
                child: Text('🧾', style: TextStyle(fontSize: 40))),
          ),
          const SizedBox(height: 20),
          Text(
            filter == 'All' ? 'No receipts yet' : 'No ${_cap(filter)} receipts',
            style: TwTheme.displayMd,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "New" to create your first receipt.',
            textAlign: TextAlign.center,
            style: TwTheme.body,
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onCreate,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: TwTheme.primary,
              ),
              child: const Text('Create Receipt',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded,
              color: TwTheme.error, size: 44),
          const SizedBox(height: 12),
          const Text('Could not load receipts', style: TwTheme.displayMd),
          const SizedBox(height: 8),
          Text(message, style: TwTheme.body, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _ReceiptsSkeleton extends StatefulWidget {
  const _ReceiptsSkeleton();
  @override
  State<_ReceiptsSkeleton> createState() => _ReceiptsSkeletonState();
}

class _ReceiptsSkeletonState extends State<_ReceiptsSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

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
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, __) => Container(
          height: 84,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TwTheme.radiusMd),
            color: TwTheme.cardBg.withOpacity(_anim.value),
          ),
        ),
      ),
    );
  }
}