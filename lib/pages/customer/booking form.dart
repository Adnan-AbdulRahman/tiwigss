import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tiwigsstrand/pages/customer/tw_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  BOOKING FORM PAGE
//  Opens when a customer taps a service in CustomerBookNowPage.
//  Dynamically shows fields based on service category:
//    Wig Making  → hair type, length, cap size, wig type
//    Revamping   → revamp details
//    Styling     → styling technique
//    Factory Wig → preferred color
//  Saves booking to Firestore collection: 'bookings'
// ─────────────────────────────────────────────────────────────────────────────
class BookingFormPage extends StatefulWidget {
  final String serviceId;
  final Map<String, dynamic> serviceData;

  const BookingFormPage({
    super.key,
    required this.serviceId,
    required this.serviceData,
  });

  @override
  State<BookingFormPage> createState() => _BookingFormPageState();
}

class _BookingFormPageState extends State<BookingFormPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double>   _fade;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // ── Contact fields ─────────────────────────────────────────────────────────
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // ── Date & time ────────────────────────────────────────────────────────────
  DateTime?  _selectedDate;
  TimeOfDay? _selectedTime;

  // ── Wig Making fields ──────────────────────────────────────────────────────
  String _capSize = 'Medium';
  String _wigType = 'Lace Front';
  final _hairTypeCtrl = TextEditingController();
  final _lengthCtrl   = TextEditingController();

  // ── Revamping fields ───────────────────────────────────────────────────────
  final _revampTypeCtrl = TextEditingController();

  // ── Styling fields ─────────────────────────────────────────────────────────
  String _stylingTechnique = 'Flat Iron';

  // ── Factory Wig fields ─────────────────────────────────────────────────────
  final _colorCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
    _prefillCustomerData();
  }

  Future<void> _prefillCustomerData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      final data = doc.data();
      _nameCtrl.text  = data?['fullName'] as String? ?? '';
      _phoneCtrl.text = data?['phone']    as String? ?? '';
      setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    _hairTypeCtrl.dispose();
    _lengthCtrl.dispose();
    _revampTypeCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: TwTheme.primary,
            onPrimary: Colors.white,
            surface: TwTheme.cardBg,
            onSurface: TwTheme.textHigh,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: TwTheme.primary,
            onPrimary: Colors.white,
            surface: TwTheme.cardBg,
            onSurface: TwTheme.textHigh,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  String get _formattedDate {
    if (_selectedDate == null) return 'Select date';
    final d = _selectedDate!;
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String get _formattedTime {
    if (_selectedTime == null) return 'Select time';
    final t      = _selectedTime!;
    final hour   = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      _showSnack('Please select a date for your booking.');
      return;
    }
    if (_selectedTime == null) {
      _showSnack('Please select a time for your booking.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnack('You must be logged in to book.');
        return;
      }

      final dt = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final Map<String, dynamic> booking = {
        'uid'           : user.uid,
        'customerName'  : _nameCtrl.text.trim(),
        'customerPhone' : _phoneCtrl.text.trim(),
        'serviceId'     : widget.serviceId,
        'service'       : widget.serviceData['name']     ?? '',
        'serviceType'   : widget.serviceData['category'] ?? '',
        'price'         : widget.serviceData['price']    ?? 0,
        'dateTime'      : Timestamp.fromDate(dt),
        'status'        : 'pending',
        'notes'         : _notesCtrl.text.trim(),
        'createdAt'     : FieldValue.serverTimestamp(),
      };

      booking.addAll(_serviceAnswers());

      await FirebaseFirestore.instance.collection('bookings').add(booking);

      if (!mounted) return;
      _showSuccessSheet();
    } catch (e) {
      if (mounted) _showSnack('Booking failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _serviceAnswers() {
    final category = widget.serviceData['category'] as String? ?? '';
    switch (category) {
      case 'Wig Making':
        return {
          'capSize'  : _capSize,
          'wigType'  : _wigType,
          'hairType' : _hairTypeCtrl.text.trim(),
          'length'   : _lengthCtrl.text.trim(),
        };
      case 'Revamping':
        return {'revampDetails': _revampTypeCtrl.text.trim()};
      case 'Styling':
        return {'stylingTechnique': _stylingTechnique};
      case 'Factory Wig':
        return {'preferredColor': _colorCtrl.text.trim()};
      default:
        return {};
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

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuccessSheet(
        serviceName: widget.serviceData['name'] as String? ?? 'Service',
        date: _formattedDate,
        time: _formattedTime,
        onDone: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name     = widget.serviceData['name']        as String? ?? 'Service';
    final price    = (widget.serviceData['price'] as num?)?.toDouble() ?? 0;
    final imageUrl = widget.serviceData['imageUrl']    as String? ?? '';
    final category = widget.serviceData['category']    as String? ?? '';
    final desc     = widget.serviceData['description'] as String? ?? '';

    return Scaffold(
      backgroundColor: TwTheme.darkBg,
      body: Container(
        decoration: const BoxDecoration(gradient: TwTheme.bgGradient),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              children: [
                _buildAppBar(context, name, category),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ServicePreviewCard(
                            name: name,
                            price: price,
                            imageUrl: imageUrl,
                            category: category,
                            desc: desc,
                          ),
                          const SizedBox(height: 24),
                          _sectionLabel('YOUR CONTACT DETAILS'),
                          const SizedBox(height: 10),
                          _buildField(_nameCtrl, 'Full Name',
                              Icons.person_outline_rounded, required: true),
                          _buildField(_phoneCtrl, 'Phone Number',
                              Icons.phone_outlined,
                              inputType: TextInputType.phone, required: true),
                          const SizedBox(height: 20),
                          _sectionLabel('PREFERRED DATE & TIME'),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _DateTimeTile(
                                  label: _formattedDate,
                                  icon: Icons.calendar_today_outlined,
                                  onTap: _pickDate,
                                  filled: _selectedDate != null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _DateTimeTile(
                                  label: _formattedTime,
                                  icon: Icons.access_time_rounded,
                                  onTap: _pickTime,
                                  filled: _selectedTime != null,
                                ),
                              ),
                            ],
                          ),
                          if (_hasSpecificFields(category)) ...[
                            const SizedBox(height: 20),
                            _sectionLabel(
                                '${category.toUpperCase()} DETAILS'),
                            const SizedBox(height: 10),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: KeyedSubtree(
                                key: ValueKey(category),
                                child: _buildServiceFields(category),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          _sectionLabel('ADDITIONAL NOTES (OPTIONAL)'),
                          const SizedBox(height: 10),
                          _buildField(
                            _notesCtrl,
                            'Any special requests or preferences\u2026',
                            Icons.notes_rounded,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 28),
                          _PriceSummary(serviceName: name, price: price),
                          const SizedBox(height: 20),
                          _ConfirmButton(
                              isLoading: _isLoading, onTap: _submitBooking),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, String name, String category) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Book Service', style: TwTheme.displayMd),
                Text(name,
                    style: TwTheme.body
                        .copyWith(color: TwTheme.accent, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TwTheme.primary.withOpacity(0.12),
              border: Border.all(color: TwTheme.primary.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(_categoryEmoji(category),
                  style: const TextStyle(fontSize: 20)),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasSpecificFields(String category) =>
      ['Wig Making', 'Revamping', 'Styling', 'Factory Wig'].contains(category);

  Widget _buildServiceFields(String category) {
    switch (category) {
      case 'Wig Making':
        return Column(
          key: const ValueKey('wigmaking'),
          children: [
            _buildField(_hairTypeCtrl, 'Hair Type (e.g. Human, Synthetic)',
                Icons.content_cut_rounded),
            _buildField(_lengthCtrl, 'Desired Length (e.g. 18 inches)',
                Icons.straighten_rounded),
            _buildDropdown('Cap Size', _capSize,
                ['Small', 'Medium', 'Large', 'Extra Large'],
                    (v) => setState(() => _capSize = v!)),
            _buildDropdown('Wig Type', _wigType,
                ['Lace Front', 'Full Lace', 'Closure', '360 Lace', 'U-Part', 'Headband'],
                    (v) => setState(() => _wigType = v!)),
          ],
        );
      case 'Revamping':
        return Column(
          key: const ValueKey('revamping'),
          children: [
            _buildField(_revampTypeCtrl,
                'What needs revamping? (e.g. Deep Condition, Re-curl)',
                Icons.auto_fix_high_rounded),
          ],
        );
      case 'Styling':
        return Column(
          key: const ValueKey('styling'),
          children: [
            _buildDropdown('Preferred Styling Technique', _stylingTechnique,
                ['Flat Iron', 'Curling Wand', 'Roller Set', 'Blow Out', 'Braiding', 'Weave Install'],
                    (v) => setState(() => _stylingTechnique = v!)),
          ],
        );
      case 'Factory Wig':
        return Column(
          key: const ValueKey('factorywig'),
          children: [
            _buildField(_colorCtrl, 'Preferred Color / Shade',
                Icons.palette_outlined),
          ],
        );
      default:
        return const SizedBox.shrink();
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

  Widget _sectionLabel(String text) =>
      Text(text, style: TwTheme.label.copyWith(fontSize: 10));

  Widget _buildField(
      TextEditingController ctrl, String hint, IconData icon, {
        TextInputType inputType = TextInputType.text,
        int maxLines = 1,
        bool required = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: inputType,
        maxLines: maxLines,
        style: const TextStyle(color: TwTheme.textHigh, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: TwTheme.textLow, fontSize: 13),
          prefixIcon: Icon(icon, color: TwTheme.textLow, size: 20),
          filled: true,
          fillColor: TwTheme.cardBg,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(TwTheme.radiusMd),
              borderSide: const BorderSide(color: TwTheme.divider)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(TwTheme.radiusMd),
              borderSide: const BorderSide(color: TwTheme.divider)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(TwTheme.radiusMd),
              borderSide: const BorderSide(color: TwTheme.primary, width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(TwTheme.radiusMd),
              borderSide: BorderSide(color: TwTheme.error)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(TwTheme.radiusMd),
              borderSide: BorderSide(color: TwTheme.error, width: 1.5)),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options,
      void Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        dropdownColor: TwTheme.cardBg,
        style: const TextStyle(color: TwTheme.textHigh, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: TwTheme.textMid, fontSize: 13),
          filled: true,
          fillColor: TwTheme.cardBg,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(TwTheme.radiusMd),
              borderSide: const BorderSide(color: TwTheme.divider)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(TwTheme.radiusMd),
              borderSide: const BorderSide(color: TwTheme.divider)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(TwTheme.radiusMd),
              borderSide: const BorderSide(color: TwTheme.primary, width: 1.5)),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SERVICE PREVIEW CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ServicePreviewCard extends StatelessWidget {
  final String name, imageUrl, category, desc;
  final double price;

  const _ServicePreviewCard({
    required this.name, required this.price, required this.imageUrl,
    required this.category, required this.desc,
  });

  String _emoji() {
    switch (category) {
      case 'Wig Making':  return '🪡';
      case 'Revamping':   return '✨';
      case 'Styling':     return '💇‍♀️';
      case 'Factory Wig': return '🏭';
      default:            return '👑';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TwTheme.radiusLg),
        color: TwTheme.cardBg,
        border: Border.all(color: TwTheme.primary.withOpacity(0.2)),
        boxShadow: TwTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(TwTheme.radiusLg)),
              child: Image.network(imageUrl,
                  height: 160, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TwTheme.primary.withOpacity(0.12),
                    border: Border.all(color: TwTheme.primary.withOpacity(0.3)),
                  ),
                  child: Center(child: Text(_emoji(),
                      style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TwTheme.titleSm),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(desc,
                            style: TwTheme.body.copyWith(fontSize: 11),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 4),
                      Text(category,
                          style: TwTheme.label.copyWith(fontSize: 10)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('GH\u20B5 ${price.toStringAsFixed(0)}',
                        style: TwTheme.label.copyWith(fontSize: 16)),
                    Text('service fee',
                        style: TwTheme.caption.copyWith(fontSize: 9)),
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

// ─────────────────────────────────────────────────────────────────────────────
//  DATE / TIME TILE
// ─────────────────────────────────────────────────────────────────────────────
class _DateTimeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _DateTimeTile({
    required this.label, required this.icon,
    required this.onTap, required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TwTheme.radiusMd),
          color: TwTheme.cardBg,
          border: Border.all(
            color: filled ? TwTheme.primary.withOpacity(0.7) : TwTheme.divider,
            width: filled ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: filled ? TwTheme.accent : TwTheme.textLow, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    color: filled ? TwTheme.textHigh : TwTheme.textLow,
                    fontSize: 12,
                    fontWeight: filled ? FontWeight.w600 : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PRICE SUMMARY
// ─────────────────────────────────────────────────────────────────────────────
class _PriceSummary extends StatelessWidget {
  final String serviceName;
  final double price;

  const _PriceSummary({required this.serviceName, required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TwTheme.radiusMd),
        color: TwTheme.cardBg,
        border: Border.all(color: TwTheme.accent.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(serviceName,
                    style: TwTheme.body.copyWith(fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
              Text('GH\u20B5 ${price.toStringAsFixed(0)}',
                  style: TwTheme.body.copyWith(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: TwTheme.divider),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(
                      color: TwTheme.textHigh,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
              Text('GH\u20B5 ${price.toStringAsFixed(0)}',
                  style: TwTheme.label.copyWith(fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CONFIRM BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _ConfirmButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _ConfirmButton({required this.isLoading, required this.onTap});

  @override
  State<_ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<_ConfirmButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp:   (_) { _ctrl.reverse(); if (!widget.isLoading) widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity, height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TwTheme.radiusMd),
            gradient: TwTheme.primaryGradient,
            boxShadow: TwTheme.primaryGlow,
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(width: 24, height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
                : const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_month_rounded,
                    color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Confirm Booking',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SUCCESS BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _SuccessSheet extends StatelessWidget {
  final String serviceName, date, time;
  final VoidCallback onDone;

  const _SuccessSheet({
    required this.serviceName, required this.date,
    required this.time, required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 40),
      decoration: BoxDecoration(
        color: TwTheme.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: TwTheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TwTheme.success.withOpacity(0.12),
              border: Border.all(color: TwTheme.success.withOpacity(0.4)),
            ),
            child: const Center(
                child: Text('🎉', style: TextStyle(fontSize: 36))),
          ),
          const SizedBox(height: 20),
          const Text('Booking Confirmed!',
              style: TextStyle(
                  color: TwTheme.textHigh,
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            'Your booking for $serviceName has been submitted.\nOur team will confirm it shortly.',
            textAlign: TextAlign.center,
            style: TwTheme.body,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _InfoPill(icon: Icons.calendar_today_outlined, label: date),
              const SizedBox(width: 10),
              _InfoPill(icon: Icons.access_time_rounded, label: time),
            ],
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: onDone,
            child: Container(
              width: double.infinity, height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(TwTheme.radiusMd),
                gradient: TwTheme.primaryGradient,
                boxShadow: TwTheme.primaryGlow,
              ),
              child: const Center(
                child: Text('Done',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: TwTheme.primary.withOpacity(0.12),
        border: Border.all(color: TwTheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: TwTheme.accent, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: TwTheme.textHigh,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}