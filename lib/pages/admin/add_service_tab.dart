import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'ad_theme.dart';



/// Add Service Tab
/// Supports: Wig Making, Revamping, Styling, Factory Wig
/// Each service type shows its own relevant fields.
/// Images work on both web (bytes) and mobile (File).
/// Saves to Firestore collection: 'wigs'
class AddServiceTab extends StatefulWidget {
  const AddServiceTab({super.key});

  @override
  State<AddServiceTab> createState() => _AddServiceTabState();
}

class _AddServiceTabState extends State<AddServiceTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double>   _fade;

  // ── Form state ─────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  String _serviceType = 'Wig Making'; // selected service category

  // Common fields
  final _nameCtrl        = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _priceCtrl       = TextEditingController();
  final _stockCtrl       = TextEditingController();

  // Wig Making specific
  final _hairTypeCtrl    = TextEditingController();
  final _lengthCtrl      = TextEditingController();
  String _capSize        = 'Medium';
  String _wigType        = 'Lace Front';
  final _processDaysCtrl = TextEditingController();

  // Revamping specific
  final _revampTypeCtrl  = TextEditingController();
  final _turnaroundCtrl  = TextEditingController();

  // Styling specific
  final _styleDurationCtrl = TextEditingController();
  String _stylingTechnique = 'Flat Iron';

  // Factory Wig specific
  final _brandCtrl    = TextEditingController();
  final _colorCtrl    = TextEditingController();
  String _wigDensity  = '150%';

  // Image picking
  File?       _imageFile;      // mobile
  Uint8List?  _imageBytes;     // web
  String?     _imageFileName;

  bool _isLoading = false;

  static const List<String> _serviceTypes = [
    'Wig Making',
    'Revamping',
    'Styling',
    'Factory Wig',
  ];

  static const Map<String, String> _serviceEmojis = {
    'Wig Making'  : '🪡',
    'Revamping'   : '✨',
    'Styling'     : '💇‍♀️',
    'Factory Wig' : '🏭',
  };

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
    _nameCtrl.dispose(); _descriptionCtrl.dispose(); _priceCtrl.dispose();
    _stockCtrl.dispose(); _hairTypeCtrl.dispose(); _lengthCtrl.dispose();
    _processDaysCtrl.dispose(); _revampTypeCtrl.dispose(); _turnaroundCtrl.dispose();
    _styleDurationCtrl.dispose(); _brandCtrl.dispose(); _colorCtrl.dispose();
    super.dispose();
  }

  // ── Image picker (web + mobile) ────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;

    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes    = bytes;
        _imageFileName = picked.name;
      });
    } else {
      setState(() {
        _imageFile     = File(picked.path);
        _imageFileName = picked.name;
      });
    }
  }

  // ── Upload image → Firebase Storage → return URL ──────────────────────────
  Future<String> _uploadImage(String docId) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('service_images')
        .child('$docId.jpg');

    UploadTask task;
    if (kIsWeb && _imageBytes != null) {
      task = ref.putData(_imageBytes!,
          SettableMetadata(contentType: 'image/jpeg'));
    } else if (!kIsWeb && _imageFile != null) {
      task = ref.putFile(_imageFile!);
    } else {
      return '';
    }

    final snapshot = await task;
    return await snapshot.ref.getDownloadURL();
  }

  // ── Save to Firestore ──────────────────────────────────────────────────────
  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // Create doc ref first so we have the ID for Storage path
      final docRef = FirebaseFirestore.instance.collection('wigs').doc();

      // Upload image if selected
      String imageUrl = '';
      if (_imageFile != null || _imageBytes != null) {
        imageUrl = await _uploadImage(docRef.id);
      }

      // Build base data
      final Map<String, dynamic> data = {
        'name'        : _nameCtrl.text.trim(),
        'description' : _descriptionCtrl.text.trim(),
        'price'       : double.tryParse(_priceCtrl.text.trim()) ?? 0,
        'stock'       : int.tryParse(_stockCtrl.text.trim()) ?? 0,
        'category'    : _serviceType,
        'imageUrl'    : imageUrl,
        'featured'    : false,
        'inStock'     : (int.tryParse(_stockCtrl.text.trim()) ?? 0) > 0,
        'createdAt'   : FieldValue.serverTimestamp(),
      };

      // Merge service-specific fields
      data.addAll(_serviceSpecificFields());

      await docRef.set(data);

      if (mounted) {
        _showSnack('Service added successfully! 🎉', isSuccess: true);
        _clearForm();
      }
    } catch (e) {
      if (mounted) _showSnack('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _serviceSpecificFields() {
    switch (_serviceType) {
      case 'Wig Making':
        return {
          'hairType'   : _hairTypeCtrl.text.trim(),
          'length'     : _lengthCtrl.text.trim(),
          'capSize'    : _capSize,
          'wigType'    : _wigType,
          'processDays': int.tryParse(_processDaysCtrl.text.trim()) ?? 7,
        };
      case 'Revamping':
        return {
          'revampType' : _revampTypeCtrl.text.trim(),
          'turnaround' : _turnaroundCtrl.text.trim(),
        };
      case 'Styling':
        return {
          'duration'         : _styleDurationCtrl.text.trim(),
          'stylingTechnique' : _stylingTechnique,
        };
      case 'Factory Wig':
        return {
          'brand'   : _brandCtrl.text.trim(),
          'color'   : _colorCtrl.text.trim(),
          'density' : _wigDensity,
        };
      default:
        return {};
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _nameCtrl.clear(); _descriptionCtrl.clear(); _priceCtrl.clear();
    _stockCtrl.clear(); _hairTypeCtrl.clear(); _lengthCtrl.clear();
    _processDaysCtrl.clear(); _revampTypeCtrl.clear(); _turnaroundCtrl.clear();
    _styleDurationCtrl.clear(); _brandCtrl.clear(); _colorCtrl.clear();
    setState(() {
      _imageFile = null; _imageBytes = null; _imageFileName = null;
      _capSize = 'Medium'; _wigType = 'Lace Front';
      _stylingTechnique = 'Flat Iron'; _wigDensity = '150%';
    });
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: isSuccess ? AdTheme.success : AdTheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Page title ───────────────────────────────────────────────
              const Text('Add Service', style: AdTheme.headingLg),
              const SizedBox(height: 4),
              const Text('Select a service type then fill in the details.',
                  style: AdTheme.body),

              const SizedBox(height: 24),

              // ── Service type selector ─────────────────────────────────────
              _buildSectionLabel('Service Type'),
              const SizedBox(height: 10),
              _buildServiceTypeSelector(),

              const SizedBox(height: 20),

              // ── Image picker ──────────────────────────────────────────────
              _buildSectionLabel('Service / Product Image'),
              const SizedBox(height: 10),
              _buildImagePicker(),

              const SizedBox(height: 20),

              // ── Common fields ─────────────────────────────────────────────
              _buildSectionLabel('General Info'),
              const SizedBox(height: 10),
              _buildField(_nameCtrl,        'Name / Title',      Icons.label_outline,       required: true),
              _buildField(_descriptionCtrl, 'Description',       Icons.description_outlined, maxLines: 3),
              _buildField(_priceCtrl,       'Price (GH₵)',       Icons.attach_money_rounded,
                  inputType: TextInputType.number, required: true),
              _buildField(_stockCtrl,       'Stock / Quantity',  Icons.inventory_2_outlined,
                  inputType: TextInputType.number, required: true),

              const SizedBox(height: 20),

              // ── Service-specific fields ───────────────────────────────────
              _buildSectionLabel('${_serviceType} Details'),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                child: KeyedSubtree(
                  key: ValueKey(_serviceType),
                  child: _buildServiceSpecificFields(),
                ),
              ),

              const SizedBox(height: 28),

              // ── Save button ───────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: AdTheme.gradientButton(
                  label: 'Add Service',
                  icon: Icons.add_circle_outline_rounded,
                  isLoading: _isLoading,
                  onTap: _saveService,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Service type pill selector ─────────────────────────────────────────────
  Widget _buildServiceTypeSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _serviceTypes.map((type) {
        final selected = _serviceType == type;
        return GestureDetector(
          onTap: () => setState(() => _serviceType = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AdTheme.rMd),
              color: selected ? AdTheme.primary.withOpacity(0.18) : AdTheme.cardBg,
              border: Border.all(
                color: selected ? AdTheme.primary.withOpacity(0.8) : AdTheme.cardBorder,
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: AdTheme.primary.withOpacity(0.2), blurRadius: 10)]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_serviceEmojis[type] ?? '✂️', style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(type,
                    style: TextStyle(
                      color: selected ? AdTheme.accent : AdTheme.textMid,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Image picker widget ────────────────────────────────────────────────────
  Widget _buildImagePicker() {
    final hasImage = _imageFile != null || _imageBytes != null;
    return GestureDetector(
      onTap: _pickImage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AdTheme.rMd),
          color: AdTheme.cardBg,
          border: Border.all(
            color: hasImage ? AdTheme.primary.withOpacity(0.6) : AdTheme.cardBorder,
            width: hasImage ? 1.5 : 1,
          ),
        ),
        child: hasImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(AdTheme.rMd),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    kIsWeb
                        ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                        : Image.file(_imageFile!, fit: BoxFit.cover),
                    Positioned(
                      bottom: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_rounded, color: Colors.white, size: 13),
                            SizedBox(width: 4),
                            Text('Change', style: TextStyle(color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AdTheme.primary.withOpacity(0.1),
                      border: Border.all(color: AdTheme.primary.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.add_photo_alternate_outlined,
                        color: AdTheme.primary, size: 24),
                  ),
                  const SizedBox(height: 10),
                  Text('Tap to upload image',
                      style: AdTheme.body.copyWith(color: AdTheme.textMid)),
                  const SizedBox(height: 2),
                  const Text('Works on web & mobile',
                      style: AdTheme.caption),
                ],
              ),
      ),
    );
  }

  // ── Service-specific field sets ────────────────────────────────────────────
  Widget _buildServiceSpecificFields() {
    switch (_serviceType) {
      case 'Wig Making':
        return Column(children: [
          _buildField(_hairTypeCtrl,    'Hair Type (e.g. Human, Synthetic)', Icons.content_cut_rounded),
          _buildField(_lengthCtrl,      'Length (e.g. 18 inches)', Icons.straighten_rounded),
          _buildDropdown('Cap Size', _capSize,
              ['Small', 'Medium', 'Large', 'Extra Large'],
              (v) => setState(() => _capSize = v!)),
          _buildDropdown('Wig Type', _wigType,
              ['Lace Front', 'Full Lace', 'Closure', '360 Lace', 'U-Part', 'Headband'],
              (v) => setState(() => _wigType = v!)),
          _buildField(_processDaysCtrl, 'Processing Time (days)',
              Icons.schedule_rounded, inputType: TextInputType.number),
        ]);

      case 'Revamping':
        return Column(children: [
          _buildField(_revampTypeCtrl, 'Revamp Service (e.g. Deep Condition, Re-curl)',
              Icons.auto_fix_high_rounded),
          _buildField(_turnaroundCtrl, 'Turnaround Time (e.g. 2-3 days)',
              Icons.timer_outlined),
        ]);

      case 'Styling':
        return Column(children: [
          _buildField(_styleDurationCtrl, 'Duration (e.g. 1 hour)',
              Icons.access_time_rounded),
          _buildDropdown('Styling Technique', _stylingTechnique,
              ['Flat Iron', 'Curling Wand', 'Roller Set', 'Blow Out', 'Braiding', 'Weave Install'],
              (v) => setState(() => _stylingTechnique = v!)),
        ]);

      case 'Factory Wig':
        return Column(children: [
          _buildField(_brandCtrl, 'Brand / Supplier', Icons.storefront_outlined),
          _buildField(_colorCtrl, 'Color / Shade',    Icons.palette_outlined),
          _buildDropdown('Density', _wigDensity,
              ['130%', '150%', '180%', '200%', '250%'],
              (v) => setState(() => _wigDensity = v!)),
        ]);

      default:
        return const SizedBox.shrink();
    }
  }

  // ── Shared field builders ──────────────────────────────────────────────────
  Widget _buildSectionLabel(String text) => Text(
        text.toUpperCase(),
        style: AdTheme.label.copyWith(fontSize: 10),
      );

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
            borderSide: const BorderSide(color: AdTheme.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdTheme.rMd),
            borderSide: const BorderSide(color: AdTheme.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdTheme.rMd),
            borderSide: const BorderSide(color: AdTheme.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdTheme.rMd),
            borderSide: const BorderSide(color: AdTheme.error),
          ),
          errorStyle: const TextStyle(color: AdTheme.error, fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'This field is required' : null
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
            borderSide: const BorderSide(color: AdTheme.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdTheme.rMd),
            borderSide: const BorderSide(color: AdTheme.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdTheme.rMd),
            borderSide: const BorderSide(color: AdTheme.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
