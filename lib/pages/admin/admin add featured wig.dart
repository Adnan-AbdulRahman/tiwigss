import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'ad_theme.dart';
import 'featured wig list.dart';


// ─────────────────────────────────────────────────────────────────────────────
//  ADMIN ADD FEATURED WIGS PAGE
//
//  NEW: Inch-based pricing system
//   • Admin sets a Base Price (default price for the wig)
//   • Admin adds inch entries: each inch length has its own price
//   • e.g. 12" → GH₵ 400,  16" → GH₵ 600,  20" → GH₵ 800
//   • All inch entries are saved to Firestore under 'inchPricing' array
//   • The 'price' field stores the base/default price
//   • On customer side, customer picks their preferred inch & sees its price
//
//  Firestore collection: 'wigs'
// ─────────────────────────────────────────────────────────────────────────────
class AdminAddFeaturedWigs extends StatefulWidget {
  const AdminAddFeaturedWigs({super.key});

  @override
  State<AdminAddFeaturedWigs> createState() => _AdminAddFeaturedWigsState();
}

class _AdminAddFeaturedWigsState extends State<AdminAddFeaturedWigs>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double>   _fade;

  int _tab = 0; // 0 = Add Form, 1 = Manage

  final _formKey        = GlobalKey<FormState>();
  bool _isLoading       = false;
  bool _isPickingImage  = false;

  // ── Core fields ────────────────────────────────────────────────────────────
  final _nameCtrl        = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _basePriceCtrl   = TextEditingController(); // default/base price
  final _stockCtrl       = TextEditingController();

  // ── Wig detail fields ──────────────────────────────────────────────────────
  final _hairTypeCtrl = TextEditingController();
  final _colorCtrl    = TextEditingController();
  final _brandCtrl    = TextEditingController();

  String _capSize  = 'Medium';
  String _wigType  = 'Frontal 13x4';
  String _density  = '150%';
  String _category = 'Wig Making';
  bool   _isFeatured = true;
  bool   _inStock    = true;

  // ── Inch pricing list ──────────────────────────────────────────────────────
  // Each entry: { 'inches': '14"', 'price': 450.0 }
  final List<Map<String, dynamic>> _inchPricing = [];

  // Controllers for the "add inch" inline form
  final _inchCtrl      = TextEditingController();
  final _inchPriceCtrl = TextEditingController();

  // ── Image state ────────────────────────────────────────────────────────────
  File?      _imageFile;
  Uint8List? _imageBytes;

  // ── Options ────────────────────────────────────────────────────────────────
  static const _categories = ['Wig Making', 'Revamping', 'Styling', 'Factory Wig'];
  static const _capSizes   = ['Petite', 'Small', 'Medium', 'Large', 'Extra Large'];
  static const _wigTypes   = ['Frontal 13x4', 'Frontal 13x6', 'Closure 6x6', 'Closure 4x4', 'Closure 5x5', 'Closure 2x6', 'No Lace', '360 Lace', 'HeadBand',];
  static const _densities  = ['130%', '150%', '180%', '200%', '250%'];

  // Common inch suggestions
  static const _commonInches = [
    '8"', '10"', '12"', '14"', '16"', '18"', '20"', '22"', '24"', '26"', '28"', '30"'
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _nameCtrl.dispose(); _descriptionCtrl.dispose();
    _basePriceCtrl.dispose(); _stockCtrl.dispose();
    _hairTypeCtrl.dispose(); _colorCtrl.dispose(); _brandCtrl.dispose();
    _inchCtrl.dispose(); _inchPriceCtrl.dispose();
    super.dispose();
  }

  // ── Add inch entry ─────────────────────────────────────────────────────────
  void _addInchEntry() {
    final inches = _inchCtrl.text.trim();
    final price  = double.tryParse(_inchPriceCtrl.text.trim());

    if (inches.isEmpty) {
      _showSnack('Please enter the inch length (e.g. 18")');
      return;
    }
    if (price == null || price <= 0) {
      _showSnack('Please enter a valid price for $inches');
      return;
    }

    // Prevent duplicates
    final exists = _inchPricing.any((e) => e['inches'] == inches);
    if (exists) {
      _showSnack('$inches is already added. Remove it first to edit.');
      return;
    }

    setState(() {
      _inchPricing.add({'inches': inches, 'price': price});
      // Sort by numeric value of inches
      _inchPricing.sort((a, b) {
        final aVal = double.tryParse((a['inches'] as String).replaceAll('"', '')) ?? 0;
        final bVal = double.tryParse((b['inches'] as String).replaceAll('"', '')) ?? 0;
        return aVal.compareTo(bVal);
      });
      _inchCtrl.clear();
      _inchPriceCtrl.clear();
    });
  }

  void _removeInchEntry(int index) {
    setState(() => _inchPricing.removeAt(index));
  }

  // ── Quick-add from suggestions ─────────────────────────────────────────────
  void _quickAddInch(String inch) {
    setState(() => _inchCtrl.text = inch);
    // Focus price field
    FocusScope.of(context).nextFocus();
  }

  // ── Image picker ───────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return;

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        if (!mounted) return;
        setState(() { _imageBytes = bytes; _imageFile = null; });
      } else {
        if (!mounted) return;
        setState(() { _imageFile = File(picked.path); _imageBytes = null; });
      }
    } catch (e) {
      debugPrint('Image picker error: $e');
      if (mounted) _showSnack('Could not open photo picker: $e');
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  // ── Upload image ───────────────────────────────────────────────────────────
  Future<String> _uploadImage(String docId) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('wigs_images')
        .child('$docId.jpg');

    UploadTask task;
    if (kIsWeb && _imageBytes != null) {
      task = ref.putData(_imageBytes!, SettableMetadata(contentType: 'image/jpeg'));
    } else if (!kIsWeb && _imageFile != null) {
      task = ref.putFile(_imageFile!);
    } else {
      return '';
    }

    final snapshot = await task;
    return await snapshot.ref.getDownloadURL();
  }

  // ── Save wig ───────────────────────────────────────────────────────────────
  Future<void> _saveFeaturedWig() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null && _imageBytes == null) {
      _showSnack('Please upload an image for the wig.');
      return;
    }
    if (_inchPricing.isEmpty) {
      _showSnack('Please add at least one inch length with a price.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final docRef = FirebaseFirestore.instance.collection('wigs').doc();
      final imageUrl = await _uploadImage(docRef.id);

      // Build the length field from inch pricing (e.g. "12", 14", 18"")
      final lengthSummary = _inchPricing
          .map((e) => e['inches'] as String)
          .join(', ');

      await docRef.set({
        // Core
        'name'        : _nameCtrl.text.trim(),
        'description' : _descriptionCtrl.text.trim(),
        'price'       : double.tryParse(_basePriceCtrl.text.trim()) ?? 0,
        'stock'       : int.tryParse(_stockCtrl.text.trim()) ?? 0,
        'category'    : _category,
        'imageUrl'    : imageUrl,
        'featured'    : _isFeatured,
        'inStock'     : _inStock,
        'createdAt'   : FieldValue.serverTimestamp(),

        // Wig details
        'hairType'    : _hairTypeCtrl.text.trim(),
        'length'      : lengthSummary,
        'capSize'     : _capSize,
        'wigType'     : _wigType,
        'density'     : _density,
        'color'       : _colorCtrl.text.trim(),
        'brand'       : _brandCtrl.text.trim(),

        // Inch-based pricing array
        'inchPricing' : _inchPricing,
      });

      if (!mounted) return;
      _showSnack('Featured wig added! 🎉', isSuccess: true);
      _clearForm();
      setState(() => _tab = 1);
    } catch (e) {
      if (mounted) _showSnack('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _nameCtrl.clear(); _descriptionCtrl.clear();
    _basePriceCtrl.clear(); _stockCtrl.clear();
    _hairTypeCtrl.clear(); _colorCtrl.clear(); _brandCtrl.clear();
    _inchCtrl.clear(); _inchPriceCtrl.clear();
    setState(() {
      _imageFile = null; _imageBytes = null;
      _inchPricing.clear();
      _capSize = 'Medium'; _wigType = 'Frontal 13x4';
      _density = '150%';   _category = 'Wig Making';
      _isFeatured = true;  _inStock  = true;
    });
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
            isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: isSuccess ? AdTheme.success : AdTheme.error,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Page header ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AdTheme.primaryGradient,
                    boxShadow: AdTheme.primaryGlow),
                child: const Center(child: Text('👑', style: TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Featured Wigs', style: AdTheme.headingLg),
                Text('Add wigs customers can order',
                    style: AdTheme.body.copyWith(fontSize: 12)),
              ]),
            ]),
            const SizedBox(height: 16),
            _TabSwitcher(selected: _tab, onTap: (i) => setState(() => _tab = i)),
          ]),
        ),

        const SizedBox(height: 16),

        // ── Content ──────────────────────────────────────────────────────────
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _tab == 0 ? _buildAddForm() : const FeaturedWigsList(),
          ),
        ),
      ]),
    );
  }

  // ── ADD FORM ───────────────────────────────────────────────────────────────
  Widget _buildAddForm() {
    return SingleChildScrollView(
      key: const ValueKey('form'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Image ────────────────────────────────────────────────────────
          _sectionLabel('WIG PHOTO'),
          const SizedBox(height: 10),
          _buildImagePicker(),

          const SizedBox(height: 22),

          // ── Core info ─────────────────────────────────────────────────────
          _sectionLabel('CORE INFORMATION'),
          const SizedBox(height: 10),
          _buildField(_nameCtrl, 'Wig Name / Title',
              Icons.label_outline_rounded, required: true),
          _buildField(_descriptionCtrl, 'Description',
              Icons.description_outlined, maxLines: 3),
          Row(children: [
            Expanded(
              child: _buildField(_basePriceCtrl, 'Base / Default Price (GH₵)',
                  Icons.attach_money_rounded,
                  inputType: TextInputType.number, required: true),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildField(_stockCtrl, 'Stock Qty',
                  Icons.inventory_2_outlined,
                  inputType: TextInputType.number, required: true),
            ),
          ]),
          _buildDropdown('Category', _category, _categories,
                  (v) => setState(() => _category = v!)),

          const SizedBox(height: 22),

          // ── INCH PRICING ──────────────────────────────────────────────────
          _sectionLabel('INCH LENGTHS & PRICES'),
          const SizedBox(height: 6),
          Text(
            'Add each available length with its price.\nCustomers will pick their preferred inch when ordering.',
            style: AdTheme.body.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 14),

          // Quick-add suggestions
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _commonInches.map((inch) {
              final alreadyAdded = _inchPricing.any((e) => e['inches'] == inch);
              return GestureDetector(
                onTap: alreadyAdded ? null : () => _quickAddInch(inch),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: alreadyAdded
                        ? AdTheme.success.withOpacity(0.12)
                        : AdTheme.cardBg,
                    border: Border.all(
                      color: alreadyAdded
                          ? AdTheme.success.withOpacity(0.4)
                          : AdTheme.cardBorder,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (alreadyAdded)
                      const Icon(Icons.check_rounded,
                          color: AdTheme.success, size: 12),
                    if (alreadyAdded) const SizedBox(width: 4),
                    Text(inch,
                        style: TextStyle(
                          color: alreadyAdded ? AdTheme.success : AdTheme.textMid,
                          fontSize: 12,
                          fontWeight: alreadyAdded
                              ? FontWeight.bold
                              : FontWeight.w500,
                        )),
                  ]),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Add inch row
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AdTheme.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add Inch Length + Price',
                    style: AdTheme.titleSm.copyWith(fontSize: 13)),
                const SizedBox(height: 12),
                Row(children: [
                  // Inch field
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _inchCtrl,
                      style: const TextStyle(color: AdTheme.textHigh, fontSize: 14),
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        hintText: 'e.g. 18" or 18 inches',
                        hintStyle: const TextStyle(
                            color: AdTheme.textLow, fontSize: 13),
                        prefixIcon: const Icon(Icons.straighten_rounded,
                            color: AdTheme.textLow, size: 18),
                        filled: true,
                        fillColor: AdTheme.surface,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AdTheme.rMd),
                            borderSide:
                            const BorderSide(color: AdTheme.cardBorder)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AdTheme.rMd),
                            borderSide:
                            const BorderSide(color: AdTheme.cardBorder)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AdTheme.rMd),
                            borderSide: const BorderSide(
                                color: AdTheme.accent, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Price field
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _inchPriceCtrl,
                      style: const TextStyle(color: AdTheme.textHigh, fontSize: 14),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Price (GH₵)',
                        hintStyle: const TextStyle(
                            color: AdTheme.textLow, fontSize: 13),
                        prefixIcon: const Icon(Icons.attach_money_rounded,
                            color: AdTheme.textLow, size: 18),
                        filled: true,
                        fillColor: AdTheme.surface,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AdTheme.rMd),
                            borderSide:
                            const BorderSide(color: AdTheme.cardBorder)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AdTheme.rMd),
                            borderSide:
                            const BorderSide(color: AdTheme.cardBorder)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AdTheme.rMd),
                            borderSide: const BorderSide(
                                color: AdTheme.accent, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Add button
                  GestureDetector(
                    onTap: _addInchEntry,
                    child: Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        gradient: AdTheme.accentGradient,
                        borderRadius: BorderRadius.circular(AdTheme.rMd),
                        boxShadow: [
                          BoxShadow(
                              color: AdTheme.accent.withOpacity(0.35),
                              blurRadius: 10)
                        ],
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: AdTheme.darkBg, size: 22),
                    ),
                  ),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Inch pricing list ─────────────────────────────────────────────
          if (_inchPricing.isNotEmpty) ...[
            Text('${_inchPricing.length} length${_inchPricing.length == 1 ? '' : 's'} added',
                style: AdTheme.label.copyWith(fontSize: 10)),
            const SizedBox(height: 10),
            Container(
              decoration: AdTheme.cardDecoration(
                  borderColor: AdTheme.accent.withOpacity(0.25)),
              child: Column(
                children: List.generate(_inchPricing.length, (i) {
                  final entry = _inchPricing[i];
                  final inches = entry['inches'] as String;
                  final price  = (entry['price'] as double);
                  final isLast = i == _inchPricing.length - 1;
                  return Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(children: [
                        // Inch badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: AdTheme.accentGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(inches,
                              style: const TextStyle(
                                  color: AdTheme.darkBg,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.arrow_forward_rounded,
                            color: AdTheme.textLow, size: 16),
                        const SizedBox(width: 12),
                        // Price
                        Expanded(
                          child: Text(
                            'GH\u20B5 ${price.toStringAsFixed(0)}',
                            style: AdTheme.label.copyWith(fontSize: 14),
                          ),
                        ),
                        // Edit price inline
                        GestureDetector(
                          onTap: () => _showEditInchSheet(i, inches, price),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AdTheme.accent.withOpacity(0.1),
                            ),
                            child: const Icon(Icons.edit_rounded,
                                color: AdTheme.accent, size: 15),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Remove
                        GestureDetector(
                          onTap: () => _removeInchEntry(i),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AdTheme.error.withOpacity(0.1),
                            ),
                            child: const Icon(Icons.close_rounded,
                                color: AdTheme.error, size: 15),
                          ),
                        ),
                      ]),
                    ),
                    if (!isLast)
                      Container(height: 1, color: AdTheme.cardBorder,
                          margin: const EdgeInsets.symmetric(horizontal: 16)),
                  ]);
                }),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AdTheme.rMd),
                color: AdTheme.cardBg,
                border: Border.all(
                    color: AdTheme.error.withOpacity(0.3),
                    style: BorderStyle.solid),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded,
                    color: AdTheme.error.withOpacity(0.7), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No inch lengths added yet. Tap a suggestion above or type a custom length.',
                    style: AdTheme.body.copyWith(fontSize: 12,
                        color: AdTheme.error.withOpacity(0.8)),
                  ),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 22),

          // ── Wig details ────────────────────────────────────────────────────
          _sectionLabel('WIG DETAILS'),
          const SizedBox(height: 10),
          _buildField(_hairTypeCtrl,
              'Hair Type (e.g. 100% Human Hair, Synthetic)',
              Icons.content_cut_rounded),
          _buildField(_colorCtrl, 'Color / Shade (e.g. Natural Black, #1B)',
              Icons.palette_outlined),
          _buildField(_brandCtrl, 'Brand / Supplier (optional)',
              Icons.storefront_outlined),
          _buildDropdown('Cap Size', _capSize, _capSizes,
                  (v) => setState(() => _capSize = v!)),
          _buildDropdown('Wig Type', _wigType, _wigTypes,
                  (v) => setState(() => _wigType = v!)),
          _buildDropdown('Density', _density, _densities,
                  (v) => setState(() => _density = v!)),

          const SizedBox(height: 22),

          // ── Toggles ────────────────────────────────────────────────────────
          _sectionLabel('VISIBILITY'),
          const SizedBox(height: 10),
          Container(
            decoration: AdTheme.cardDecoration(),
            child: Column(children: [
              _ToggleTile(
                icon: Icons.star_rounded,
                label: 'Mark as Featured',
                subtitle: 'Shows in the Featured Wigs section on homepage',
                value: _isFeatured,
                color: AdTheme.accent,
                onChanged: (v) => setState(() => _isFeatured = v),
              ),
              Container(height: 1, color: AdTheme.cardBorder,
                  margin: const EdgeInsets.symmetric(horizontal: 16)),
              _ToggleTile(
                icon: Icons.check_circle_outline_rounded,
                label: 'In Stock',
                subtitle: 'Customers can order this wig',
                value: _inStock,
                color: AdTheme.success,
                onChanged: (v) => setState(() => _inStock = v),
              ),
            ]),
          ),

          const SizedBox(height: 28),

          // ── Submit ─────────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: AdTheme.gradientButton(
              label: 'Add Featured Wig',
              icon: Icons.add_circle_outline_rounded,
              isLoading: _isLoading,
              onTap: _saveFeaturedWig,
            ),
          ),
        ]),
      ),
    );
  }

  // ── Edit inch price bottom sheet ───────────────────────────────────────────
  void _showEditInchSheet(int index, String inches, double currentPrice) {
    final editCtrl = TextEditingController(text: currentPrice.toStringAsFixed(0));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AdTheme.cardBg,
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AdTheme.rXl)),
            border: Border.all(color: AdTheme.cardBorder),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Edit Price for $inches',
                style: const TextStyle(
                    color: AdTheme.textHigh,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: editCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: AdTheme.textHigh, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Price (GH₵) for $inches',
                labelStyle: const TextStyle(color: AdTheme.textMid),
                prefixIcon: const Icon(Icons.attach_money_rounded,
                    color: AdTheme.textLow),
                filled: true,
                fillColor: AdTheme.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AdTheme.rMd),
                    borderSide: const BorderSide(color: AdTheme.cardBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AdTheme.rMd),
                    borderSide: const BorderSide(color: AdTheme.cardBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AdTheme.rMd),
                    borderSide:
                    const BorderSide(color: AdTheme.accent, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: AdTheme.gradientButton(
                label: 'Update Price',
                icon: Icons.check_rounded,
                gradient: AdTheme.accentGradient,
                onTap: () {
                  final newPrice = double.tryParse(editCtrl.text.trim());
                  if (newPrice != null && newPrice > 0) {
                    setState(() => _inchPricing[index]['price'] = newPrice);
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Image picker widget ────────────────────────────────────────────────────
  Widget _buildImagePicker() {
    final hasImage = _imageFile != null || _imageBytes != null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AdTheme.rMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AdTheme.rMd),
        onTap: _isPickingImage ? null : _pickImage,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AdTheme.rMd),
            color: AdTheme.cardBg,
            border: Border.all(
              color: hasImage
                  ? AdTheme.accent.withOpacity(0.7)
                  : AdTheme.cardBorder,
              width: hasImage ? 1.5 : 1,
            ),
          ),
          child: hasImage
              ? Stack(fit: StackFit.expand, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AdTheme.rMd),
              child: kIsWeb
                  ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                  : Image.file(_imageFile!, fit: BoxFit.cover),
            ),
            Positioned(
              bottom: 10, right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.edit_rounded, color: Colors.white, size: 13),
                  SizedBox(width: 5),
                  Text('Change photo',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            Positioned(
              top: 10, left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AdTheme.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('\u2B50 Featured',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ])
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AdTheme.accent.withOpacity(0.1),
                border:
                Border.all(color: AdTheme.accent.withOpacity(0.3)),
              ),
              child: _isPickingImage
                  ? const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AdTheme.accent),
              )
                  : const Icon(Icons.add_photo_alternate_outlined,
                  color: AdTheme.accent, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
                _isPickingImage
                    ? 'Opening photo picker\u2026'
                    : 'Tap to upload wig photo',
                style: AdTheme.titleSm),
            const SizedBox(height: 4),
            Text('Works on web & mobile  \u00b7  JPG / PNG',
                style: AdTheme.caption),
          ]),
        ),
      ),
    );
  }

  // ── Field builders ─────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) =>
      Text(text, style: AdTheme.label.copyWith(fontSize: 10));

  Widget _buildField(
      TextEditingController ctrl,
      String hint,
      IconData icon, {
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
        style: const TextStyle(color: AdTheme.textHigh, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AdTheme.textLow, fontSize: 13),
          prefixIcon: Icon(icon, color: AdTheme.textLow, size: 20),
          filled: true,
          fillColor: AdTheme.cardBg,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AdTheme.rMd),
              borderSide: const BorderSide(color: AdTheme.cardBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AdTheme.rMd),
              borderSide: const BorderSide(color: AdTheme.cardBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AdTheme.rMd),
              borderSide:
              const BorderSide(color: AdTheme.accent, width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AdTheme.rMd),
              borderSide: const BorderSide(color: AdTheme.error)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AdTheme.rMd),
              borderSide: const BorderSide(color: AdTheme.error, width: 1.5)),
          errorStyle: const TextStyle(color: AdTheme.error, fontSize: 11),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: required
            ? (v) =>
        (v == null || v.trim().isEmpty) ? 'This field is required' : null
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
        dropdownColor: AdTheme.surface,
        style: const TextStyle(color: AdTheme.textHigh, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AdTheme.textMid, fontSize: 13),
          filled: true,
          fillColor: AdTheme.cardBg,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AdTheme.rMd),
              borderSide: const BorderSide(color: AdTheme.cardBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AdTheme.rMd),
              borderSide: const BorderSide(color: AdTheme.cardBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AdTheme.rMd),
              borderSide:
              const BorderSide(color: AdTheme.accent, width: 1.5)),
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

// ── Tab switcher ──────────────────────────────────────────────────────────────
class _TabSwitcher extends StatelessWidget {
  final int selected;
  final void Function(int) onTap;
  const _TabSwitcher({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AdTheme.darkBg.withOpacity(0.6),
        borderRadius: BorderRadius.circular(AdTheme.rMd),
        border: Border.all(color: AdTheme.cardBorder),
      ),
      child: Stack(children: [
        AnimatedAlign(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          alignment:
          selected == 0 ? Alignment.centerLeft : Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.5,
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AdTheme.rSm),
                gradient: AdTheme.accentGradient,
                boxShadow: [
                  BoxShadow(
                      color: AdTheme.accent.withOpacity(0.35), blurRadius: 10)
                ],
              ),
            ),
          ),
        ),
        Row(children: [
          _TabItem(label: '\u2795  Add Wig', active: selected == 0, onTap: () => onTap(0)),
          _TabItem(label: '\uD83D\uDCCB  Manage',  active: selected == 1, onTap: () => onTap(1)),
        ]),
      ]),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool   active;
  final VoidCallback onTap;
  const _TabItem({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          style: TextStyle(
            color: active ? Colors.white : AdTheme.textMid,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
          child: Center(child: Text(label)),
        ),
      ),
    );
  }
}

// ── Toggle tile ───────────────────────────────────────────────────────────────
class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String   label, subtitle;
  final bool     value;
  final Color    color;
  final void Function(bool) onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: color.withOpacity(0.12)),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AdTheme.titleSm.copyWith(fontSize: 13)),
            const SizedBox(height: 2),
            Text(subtitle, style: AdTheme.caption.copyWith(fontSize: 10)),
          ]),
        ),
        Switch.adaptive(value: value, onChanged: onChanged, activeColor: color),
      ]),
    );
  }
}
